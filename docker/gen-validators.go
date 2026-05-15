//go:build ignore

package main

import (
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
)

// Dev-only generator. Emits a single-validator JSON file matching the
// FullValidatorInfo schema consumed by cmd/strawberry/main.go.
// NEVER use the resulting keys in production.
func main() {
	pub, prv, err := ed25519.GenerateKey(nil)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	out := []map[string]any{{
		"index":               0,
		"address":             "::",
		"port":                30000,
		"ed25519_public_key":  hex.EncodeToString(pub),
		"ed25519_private_key": hex.EncodeToString(prv),
	}}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "\t")
	if err := enc.Encode(out); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
