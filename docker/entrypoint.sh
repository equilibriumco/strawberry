#!/bin/sh
# Dispatch between strawberry's normal validator-node mode and the JAM fuzz
# conformance target mode, per the standard target packaging spec:
# https://github.com/davxy/jam-conformance/tree/main/fuzz-proto#standard-target-packaging

set -eu

if [ -z "${JAM_FUZZ:-}" ]; then
    # Normal mode: run the validator node from /app using baked configs.
    cd /app
    exec /app/strawberry "$@"
fi

# Fuzz mode: required env vars per spec.
missing=
for v in JAM_FUZZ_SPEC JAM_FUZZ_DATA_PATH JAM_FUZZ_SOCK_PATH; do
    eval "val=\${$v:-}"
    if [ -z "$val" ]; then
        missing="$missing $v"
    fi
done
if [ -n "$missing" ]; then
    echo "JAM_FUZZ is set but required variable(s) missing:$missing" >&2
    exit 1
fi

case "$JAM_FUZZ_SPEC" in
    tiny) bin=/app/strawberry-conformance-tiny ;;
    full) bin=/app/strawberry-conformance-full ;;
    *)
        echo "JAM_FUZZ_SPEC must be 'tiny' or 'full', got: $JAM_FUZZ_SPEC" >&2
        exit 1
        ;;
esac

mkdir -p "$JAM_FUZZ_DATA_PATH"
cd "$JAM_FUZZ_DATA_PATH"

# The conformance binary reads JAM_FUZZ_SOCK_PATH and JAM_FUZZ_LOG_LEVEL from
# its environment; passing them through implicitly.
exec "$bin" "$@"
