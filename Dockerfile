FROM golang:1.22 AS op

WORKDIR /app

ENV REPO=https://github.com/ethereum-optimism/optimism.git
ENV VERSION=v1.10.0
ENV COMMIT=910c9ade39c0bcdff5f2badd94efbe016a428e73
RUN git clone $REPO --branch op-node/$VERSION --single-branch . && \
    git switch -c branch-$VERSION && \
    bash -c '[ "$(git rev-parse HEAD)" = "$COMMIT" ]'

RUN make VERSION=$VERSION op-node op-batcher op-proposer

RUN cd op-alt-da && \
    make VERSION=$VERSION da-server

FROM rust:1.82 AS reth

ARG FEATURES=jemalloc,asm-keccak,optimism

WORKDIR /app

RUN apt-get update && apt-get -y upgrade && apt-get install -y git libclang-dev pkg-config curl build-essential

ENV REPO=https://github.com/paradigmxyz/reth.git
ENV VERSION=v1.1.2
ENV COMMIT=496bf0bf715f0a1fafc198f8d72ccd71913d1a40
RUN git clone $REPO --branch $VERSION --single-branch . && \
    git switch -c branch-$VERSION && \
    bash -c '[ "$(git rev-parse HEAD)" = "$COMMIT" ]'

RUN cargo build --bin op-reth --features $FEATURES --profile maxperf --manifest-path crates/optimism/bin/Cargo.toml

FROM golang:1.22 AS geth

WORKDIR /app

ENV REPO=https://github.com/ethereum-optimism/op-geth.git
ENV VERSION=v1.101411.2
ENV COMMIT=3dd9b0274bae3d3d2c80ef517563a360108e8cf6
RUN git clone $REPO --branch $VERSION --single-branch . && \
    git switch -c branch-$VERSION && \
    bash -c '[ "$(git rev-parse HEAD)" = "$COMMIT" ]'

RUN go run build/ci.go install -static ./cmd/geth


FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y jq curl supervisor && \
    rm -rf /var/lib/apt/lists

WORKDIR /app

COPY --from=op /app/op-alt-da/bin/da-server ./
COPY --from=op /app/op-node/bin/op-node ./
COPY --from=op /app/op-batcher/bin/op-batcher ./
COPY --from=op /app/op-proposer/bin/op-proposer ./
COPY --from=reth /app/target/maxperf/op-reth ./
COPY --from=geth /app/build/bin/geth ./
