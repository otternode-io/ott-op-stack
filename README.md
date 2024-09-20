# Build
docker buildx build --push --platform=linux/amd64,linux/arm64 -f Dockerfile.op-stack -t ghcr.io/otternode-io/ott-op-stack  .
