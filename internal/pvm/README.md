# Polkadot Virtual Machine (PVM)

This package implements the **Polkadot Virtual Machine (PVM)** as specified in the **Gray Paper Appendix A and B v0.7.2 (GP)**. 
It provides a deterministic execution environment for services in the JAM network.
The comments refer to the respective equations in the GP.

## Overview

The PVM is a stack-based virtual machine with:
- **32-bit address space** (2³² bytes)
- **13 general-purpose registers** (φ)
- **Page-based memory** (4KB pages)
- **Gas metering** for execution cost accounting
- **Host calls** (ecalli) for interacting with the runtime environment

## Directory Structure

```
internal/pvm/
├── common.go          # Core types, memory, registers, and context structures
├── exit_reason.go     # Exit/error types (halt, panic, out-of-gas, page fault)
├── initialisation.go  # Memory and register initialization (eq. A.37, A.42, A.43)
├── instance.go        # VM instance creation and core execution primitives
├── instruction_codes.go # Opcode constants (A.5.1–A.5.13)
├── instructions.go    # Gas costs, register definitions, opcode validation
├── invocations.go     # Whole-program and basic invocation (ΨM, ΨH, Ψ)
├── mutations.go       # Instruction implementations (Trap, Load, Store, etc.)
├── program.go         # Blob parsing, deblobbing, instruction decoding
├── step.go            # Single-step execution (Ψ1)
└── host_call/         # Host call implementations
    ├── common.go           # Shared constants, result codes, utilities
    ├── general_functions.go # Gas, Fetch, Lookup, Read, Write, Info
    ├── accumulate_functions.go # Bless, Assign, Designate, Transfer, etc.
    └── refine_functions.go     # HistoricalLookup, Export, Machine, Invoke, etc.
```

## Core Components

### Memory (`common.go`)

Memory is organized into segments with access control:

| Segment | Purpose | Access |
|---------|---------|--------|
| **ro** | Read-only data (program constants) | Read-Only |
| **rw** | Read-write data (heap, globals) | Read-Write |
| **stack** | Call stack | Read-Write |
| **args** | Program arguments | Read-Only |

- **Page size** (`Z_P`): 4KB (2¹²)
- **Zone size** (`Z_Z`): 64KB (2¹⁶)
- Addresses below 2¹⁶ are forbidden (reserved zone)
- `sbrk` extends the heap within the RW segment

### Registers (`instructions.go`)

| Reg | Name | Purpose |
|-----|------|---------|
| R0  | ra   | Return address (2³² − 2¹⁶ for return-to-host) |
| R1  | sp   | Stack pointer |
| R2  | t0   | Temporary |
| R3  | t1   | Temporary |
| R4  | t2   | Temporary |
| R5  | s0   | Saved |
| R6  | s1   | Saved |
| R7  | a0   | Argument/return value |
| R8  | a1   | Argument/return length |
| R9  | a2   | Argument |
| R10 | a3   | Argument |
| R11 | a4   | Argument |
| R12 | a5   | Argument |

### Exit Reasons (`exit_reason.go`)

| Error | Symbol | Description |
|-------|--------|-------------|
| `ErrHalt` | ∎ | Normal program termination |
| `ErrPanic` | ☇ | Irregular termination (trap, invalid operation) |
| `ErrOutOfGas` | ∞ | Gas exhausted |
| `ErrPageFault` | F | Invalid memory access |
| `ErrHostCall` | h | Host call in progress |

## Execution Model

### Invocations

1. **InvokeWholeProgram** (ΨM) — Full program invocation:
   - Parses blob
   - Initializes memory and registers
   - Instantiates VM
   - Runs until halt, panic, out-of-gas, or page fault

2. **InvokeHostCall** (ΨH) — Runs until a host call or termination

3. **InvokeBasic** (Ψ) — Executes a single basic block or until host call

4. **step** (Ψ1) — Executes one instruction

### Program Format

Programs are delivered as **blobs** containing:
- **Program memory sizes** (RO, RW, stack, initial heap pages)
- **RO data** — Read-only constants
- **RW data** — Initialized read-write data
- **Code and jump table** — JAM-encoded bytecode

The **deblob** operation extracts:
- **Code** — Instruction stream
- **Bitmask** — Instruction boundaries
- **Jump table** — For indirect jumps (`djump`)

### Instruction Set

The PVM implements a RISC-like instruction set (see `instruction_codes.go`):

- **Control flow**: Trap, Fallthrough, Jump, JumpInd, LoadImmJump, LoadImmJumpInd, Branch variants
- **Memory**: Load/Store (U8, U16, U32, U64, signed/unsigned variants)
- **Arithmetic**: Add, Sub, Mul, Div, Rem, shifts, rotations
- **Bitwise**: And, Or, Xor, AndInv, OrInv, Xnor
- **Other**: MoveReg, Sbrk, CountSetBits, Leading/TrailingZeroBits, SignExtend, Cmov
- **Host**: Ecalli — triggers a host call with an immediate index

## Host Calls

Host calls allow programs to interact with the runtime. The `host_call` subpackage implements:

### General Functions
- **gas** — Return remaining gas
- **fetch** — Fetch chain constants, entropy, authorizer hash, work metadata
- **lookup** — State lookup
- **read** — Read from service state
- **write** — Write to service state
- **info** — Service/block metadata

### Accumulate Functions
- **bless** — Set manager, assigners, designate service
- **assign** — Assign cores to services
- **designate** — Designate service for creation
- **checkpoint** — Create checkpoint
- **new** — Create new service
- **upgrade** — Upgrade service
- **transfer** — Transfer balance
- **eject** — Eject service
- **query** — Query service state
- **solicit** — Solicit service
- **forget** — Forget solicitation
- **yield** — Yield execution
- **provide** — Provide preimage

### Refine Functions
- **historical_lookup** — Look up historical state
- **export** — Export segments
- **machine** — Get machine state
- **peek** — Peek at memory
- **poke** — Write to memory
- **pages** — Memory page info
- **invoke** — Invoke nested PVM
- **expunge** — Remove data

### Result Codes

Host calls return status via `Code`:
- `OK` — Success
- `NONE` — Item does not exist
- `WHAT` — Name unknown
- `OOB` — Out of bounds
- `WHO` — Index unknown
- `FULL` — Storage full
- `CORE` — Core index unknown
- `CASH` — Insufficient funds
- `LOW` — Gas limit too low
- `HUH` — Invalid solicitation/forget state

## Context Types

- **AccumulateContext** — Used during accumulation phase (block building)
- **RefineContextPair** — Used during refinement (execution with integrated PVM map)
- **IntegratedPVM** — Captures code, RAM, and instruction counter for nested invocations

## Constants (from specification)

| Constant | Value | Description |
|----------|-------|-------------|
| `AddressSpaceSize` | 2³² | Total address space |
| `PageSize` | 4KB | Memory page size |
| `MemoryZoneSize` | 64KB | Zone size |
| `InputDataSize` | 16MB | Max input/args size |
| `DynamicAddressAlignment` | 2 | Indirect jump alignment |
| `AddressReturnToHost` | 2³² − 2¹⁶ | Special return address |

