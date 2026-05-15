# syntax=docker/dockerfile:1.7

############################
# Stage 1: builder
############################
FROM --platform=linux/amd64 golang:1.25.5-bookworm AS builder

ENV RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        make \
        pkg-config \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
       | sh -s -- -y --default-toolchain stable --profile minimal \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Validator node binary + both conformance binaries (tiny and full specs).
RUN make build \
    && make build-conformance \
    && make build-conformance-full

# Dev-only ed25519 key pair for the baked test_validators.json (normal mode).
RUN mkdir -p /out && go run docker/gen-validators.go > /out/test_validators.json

############################
# Stage 2: runtime
############################
FROM --platform=linux/amd64 debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1000 strawberry

WORKDIR /app

COPY --from=builder /src/strawberry                       /app/strawberry
COPY --from=builder /src/pkg/conformance/bin/strawberry      /app/strawberry-conformance-tiny
COPY --from=builder /src/pkg/conformance/bin/strawberry-full /app/strawberry-conformance-full
COPY --from=builder /src/appconfig.json                   /app/appconfig.json
COPY --from=builder /out/test_validators.json             /app/test_validators.json
COPY --from=builder /src/docker/entrypoint.sh             /app/entrypoint.sh

RUN sed -i 's/"validatorIndex": *[0-9]*/"validatorIndex": 0/' /app/appconfig.json \
    && chmod +x /app/entrypoint.sh \
    && chown -R strawberry:strawberry /app

USER strawberry
EXPOSE 30000/udp

ENTRYPOINT ["/app/entrypoint.sh"]
