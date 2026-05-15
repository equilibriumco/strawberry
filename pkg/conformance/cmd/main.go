package main

import (
	"flag"
	"log"
	"net/http"
	_ "net/http/pprof"
	"os"

	"github.com/eigerco/strawberry/pkg/conformance"
	pkglog "github.com/eigerco/strawberry/pkg/log"
)

func main() {
	defaultSocket := "/tmp/jam_target.sock"
	if v := os.Getenv("JAM_FUZZ_SOCK_PATH"); v != "" {
		defaultSocket = v
	}

	socketPath := flag.String("socket", defaultSocket, "Path to the socket for the fuzzer to connect to (overrides JAM_FUZZ_SOCK_PATH)")
	pprofAddr := flag.String("pprof", "", "Address for pprof HTTP server (e.g., localhost:6060)")
	flag.Parse()

	// Ensure no extra positional arguments
	if flag.NArg() > 0 {
		log.Fatalf("unexpected arguments: %v", flag.Args())
	}

	if lvl := os.Getenv("JAM_FUZZ_LOG_LEVEL"); lvl != "" {
		parsed, err := pkglog.ParseLogLevel(lvl)
		if err != nil {
			log.Fatalf("invalid JAM_FUZZ_LOG_LEVEL %q: %v", lvl, err)
		}
		pkglog.Init(pkglog.Options{LogLevel: parsed})
	}

	// Start pprof server if address provided
	if *pprofAddr != "" {
		go func() {
			log.Printf("Starting pprof server on %s", *pprofAddr)
			if err := http.ListenAndServe(*pprofAddr, nil); err != nil {
				log.Printf("pprof server error: %v", err)
			}
		}()
	}

	appName := []byte("strawberry")
	appVersion := conformance.Version{Major: 0, Minor: 0, Patch: 2}
	jamVersion := conformance.Version{Major: 0, Minor: 7, Patch: 2}
	features := conformance.FeatureAncestryAndFork
	node := conformance.NewNode(*socketPath, appName, appVersion, jamVersion, features)
	if err := node.Start(); err != nil {
		log.Fatalf("Failed to start Node: %v", err)
	}
}
