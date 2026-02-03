# Strawberry Architecture Overview

Strawberry is a JAM (JOIN-ACCUMULATE MACHINE) client implementation for Polkadot, written in Go. It is developed by Eiger and follows the JAM graypaper specification (v0.7.2).

## Project Structure

```
strawberry/
├── cmd/                           # Command-line executables
│   ├── strawberry/                # Main node application (Milestone 2)
├── pkg/                           # Public packages (stable APIs)
│   ├── network/                   # Networking layer (QUIC, P2P)
│   ├── conformance/               # JAM conformance testing node (Milestone 1)
│   ├── db/                        # Database abstraction (PebbleDB)
│   ├── log/                       # Logging utilities
│   ├── serialization/             # JAM codec implementation
├── internal/                      # Internal packages (core implementation)
│   ├── block/                     # Block structures & operations (Extrinsics)
│   ├── state/                     # Chain state management (Merklization, Serialization, Block Sealing)
│   ├── statetransition/           # State transition logic
│   ├── store/                     # State & data persistence
│   ├── chain/                     # Chain service (Finalization, Fork handling)
│   ├── validator/                 # Validator management (connections, keys, shards)
│   ├── work/                      # Work packages & bundles
│   ├── service/                   # Service accounts & state
│   ├── crypto/                    # Cryptographic operations (Including Bandersnatch via Rust FFI)
│   ├── pvm/                       # Polkadot Virtual Machine
│   ├── guaranteeing/              # Work report guarantees (Guarantee Extrinsic validation and production)
│   ├── assuring/                  # Availability assurance (Assurance Extrinsic validation and production)
│   ├── disputing/                 # Dispute mechanisms (Dispute Extrinsic validation and production)
│   ├── safrole/                   # Block ticket algorithm 
│   ├── jamtime/                   # Time slot management
│   ├── merkle/                    # Merkle tree structures
│   ├── erasurecoding/             # Reed-Solomon erasure coding (Rust FFI)
│   ├── d3l/                       # Data Availability Layer (Segment fetching)
│   ├── merkle/                    # Merkle tree structures
│   ├── refine/                    # PVM Refinement operations
│   ├── safemath/                  # Safe arithmetic operations
│   └── authorization/             # PVM Authorization mechanisms
├── bandersnatch/                  # Rust FFI: Bandersnatch cryptography
├── erasurecoding/                 # Rust FFI: Reed-Solomon encoding
└── tests/                         # Integration & simulation tests
```

## Core Components

### 1. Network Layer (`pkg/network/`)

The networking layer provides peer-to-peer communication using QUIC protocol.

| Component | Purpose |
|-----------|---------|
| `node/` | Central manager for peer connections and protocol handling |
| `transport/` | QUIC-based transport layer via `quic-go` |
| `protocol/` | ALPN-based protocol negotiation and message routing |
| `handlers/` | Message handlers (work packages, tickets, blocks, segments) |
| `peer/` | Peer discovery and connection management |
| `cert/` | TLS certificate generation with Ed25519 keys |

### 2. State Management (`internal/state/`, `internal/statetransition/`)

Manages the complete system state and state transitions.

**State Structure:**
```
State
├── Services            # Service accounts with code and storage
├── ValidatorState      # Current, archived, and queued validators
├── CoreAssignments     # Work-reports assigned to cores
├── RecentHistory       # Recent block information
├── TimeslotIndex       # Current time slot
├── EntropyPool         # Randomness for consensus
├── ActivityStatistics  # Validator performance metrics
├── AccumulationQueue   # Pending work-reports
└── PastJudgements      # Dispute history
```

**State Transition Flow:**
1. Verify block header (merkle proof validation)
2. Parallel validation of extrinsics (preimages, guarantees, assurances, disputes)
3. Update state components
4. Persist new state root

### 3. Block Processing (`internal/block/`, `internal/chain/`)

Handles block structure, validation, and chain management.

**Block Structure:**
```
Block
├── Header
│   ├── ParentHash
│   ├── TimeSlotIndex
│   ├── BlockAuthorIndex
│   ├── RecentHistoryRoot
│   ├── EntropySource
│   └── Seals
└── Extrinsic
    ├── TicketExtrinsic (ET)       # Safrole tickets
    ├── PreimageExtrinsic (EP)     # Preimage data
    ├── GuaranteesExtrinsic (EG)   # Work report guarantees
    ├── AssurancesExtrinsic (EA)   # Availability assurances
    └── DisputeExtrinsic (ED)      # Dispute verdicts
```

### 4. Polkadot Virtual Machine (`internal/pvm/`)

Executes service code in a sandboxed environment.

| Component | Purpose |
|-----------|---------|
| `program.go` | Program blob parsing and validation |
| `step.go` | Single-step instruction execution |
| `mutations.go` | State mutation operations |
| `host_call/` | Host function implementations |

**Memory Model:**
- Read-only data section
- Read-write data section
- Heap (grows upward)
- Stack (grows downward)

### 5. Cryptography (`internal/crypto/`)

Cryptographic operations supporting JAM's security requirements.

| Scheme | Implementation | Purpose |
|--------|----------------|---------|
| Bandersnatch | Rust FFI | Ring VRF signatures for anonymous validator selection |
| Ed25519 | Go native | Standard digital signatures |
| Blake2b | Go native | Hashing |

### 6. Validator & Consensus (`internal/validator/`, `internal/safrole/`)

Manages validator state and the Safrole block production algorithm.

- **ValidatorManager**: Key management and validator state
- **ValidatorGrid**: Core-to-validator assignments
- **Safrole**: Decentralized, fair block production

### 7. Work Execution Pipeline

```
Work Package Submission
        │
        ▼
┌───────────────────┐
│  Network Handler  │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  PVM Execution    │
│  (if refinement)  │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Work Report      │
│  Generation       │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Guarantor        │
│  Selection        │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Signature        │
│  Aggregation      │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│  Block Inclusion  │
│  & Accumulation   │
└───────────────────┘
```

### 8. Data Availability (`internal/erasurecoding/`, `internal/d3l/`)

Ensures data availability through erasure coding.

- **Reed-Solomon Encoding**: Via Rust FFI for performance
- **Segment Fetcher**: Retrieves segments from the D3L (Data Dissemination Layer)
- **Shards Store**: Persists encoded data shards

### 9. Storage (`internal/store/`, `pkg/db/`)

Layered storage architecture using PebbleDB.

| Store | Purpose |
|-------|---------|
| Chain Store | Blocks and headers |
| Trie Store | Merkle trie for state |
| Ticket Store | Safrole ticket state |
| Shards Store | Erasure-coded data shards |

## Key Dependencies

### Go Dependencies
- `cockroachdb/pebble`: Key-value storage
- `quic-go`: QUIC protocol implementation
- `rs/zerolog`: Structured logging
- `golang.org/x/crypto`: Cryptographic primitives
- `ebitengine/purego`: FFI without CGO

### Rust FFI Components
- **Bandersnatch** (`bandersnatch/`): Ring VRF signatures
- **Erasure Coding** (`erasurecoding/`): Reed-Solomon encoding

## Design Principles

### 1. Modular Package Structure
- `internal/` packages hide implementation details
- `pkg/` packages expose stable, public APIs
- Single responsibility per package

### 2. Concurrent Processing
- Independent validation steps run in parallel via `errgroup`
- Configurable concurrency for debugging

### 3. FFI via Pure Go
- Uses `purego` to load Rust libraries without CGO overhead
- Dynamic linking at runtime
- Cross-platform support (macOS, Linux)

### 4. Performance Optimizations
- Cached state roots to avoid re-merkleization
- Fast-path header verification
- Parallel extrinsic validation

## Build Configuration

### Build Tags
| Tag | Purpose |
|-----|---------|
| `tiny` | Minimal configuration for quick tests |
| `conformance` | Conformance test configuration |
| `full` | Full protocol parameters |

### Prerequisites
- Go 1.25.5+
- Rust 1.81.1+
- Make

### Common Commands
```bash
make build              # Build main binary
make test               # Run unit tests
make integration        # Run integration tests
make build-conformance  # Build conformance runner
make lint               # Run linter
```

## Testing

### Unit Tests
Located alongside source files in `internal/` packages.

### Integration Tests (`tests/integration/`)
- Trace execution (safrole, storage, preimages, fuzzy)
- PVM execution
- State transitions
- Codec encoding/decoding
- Merkle structures
- Disputes and assurances

### Conformance Tests (`pkg/conformance/`)
Formal JAM specification conformance testing with external fuzzer support.

## Protocol Compliance

- **JAM Graypaper Version**: 0.7.2
- **Features**: Ancestry validation, fork handling
- **Milestone 1**: State-transitioning conformance tests (completed)
