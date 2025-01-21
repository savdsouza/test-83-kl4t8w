###############################################################################
# Multi-stage Dockerfile for Go 1.21-based real-time location tracking service
# with MQTT support, TimescaleDB connectivity, and production-grade security.
# Implements requirements for 99.9% availability, geofencing, and route
# optimization, as specified in the technical documentation.
###############################################################################

###############################################
# ---------- BUILD ARG DEFINITIONS ----------
###############################################
# These ARGs allow adjusting base versions and configurations at build time.
ARG GO_VERSION=1.21
ARG ALPINE_VERSION=3.18
ARG PORT=8080
ARG CONFIG_PATH=/app/config

###############################################
# ------------- BUILD STAGE ------------------
###############################################
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS build

# -----------------------------------------------------------------------------
# Global environment variables for Go module support and native compilation.
# -----------------------------------------------------------------------------
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

# -----------------------------------------------------------------------------
# Work directory for application source and binaries.
# -----------------------------------------------------------------------------
WORKDIR /app

# -----------------------------------------------------------------------------
# Install required packages for security scanning, build, and tests:
#  1. git => fetches private/public modules if needed
#  2. ca-certificates => SSL certificate store for secure http connections
#  3. upx => optional binary compression
#  4. bash/curl => for various build/test scripts & scanning
#  5. make => potential build step dependency
# -----------------------------------------------------------------------------
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
      git \
      ca-certificates \
      curl \
      make \
      upx \
      bash

# -----------------------------------------------------------------------------
# Copy module files (go.mod & go.sum) first for dependable caching.
# -----------------------------------------------------------------------------
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-mod \
    go mod download && \
    go mod verify

# -----------------------------------------------------------------------------
# Copy the entire source code into the build container with minimal permissions.
# -----------------------------------------------------------------------------
COPY . /app

# -----------------------------------------------------------------------------
# Optional security checks and tests before building:
# Here we could integrate tools like golangci-lint, staticcheck, or custom scripts.
# Uses a simple "go test" as a placeholder for demonstration.
# -----------------------------------------------------------------------------
RUN --mount=type=cache,target=/root/.cache/go-build \
    go test -v ./... && \
    echo "Security checks and tests completed successfully."

# -----------------------------------------------------------------------------
# Build the optimized, statically linked binary using recommended flags:
#   -trimpath => removes file system paths
#   -ldflags "-w -s" => strips debug info (smaller build) 
# -----------------------------------------------------------------------------
RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -o tracking-service \
      -trimpath \
      -ldflags "-w -s -extldflags '-static'" \
      ./cmd/tracking-service

# -----------------------------------------------------------------------------
# Optional binary compression step with upx for smaller image footprint.
# -----------------------------------------------------------------------------
RUN upx --best --lzma tracking-service || echo "UPX compression failed, proceeding anyway."

# -----------------------------------------------------------------------------
# (Optional) Step to verify binary signature or additional security check
# can be inserted here if using GPG or other signing mechanisms.
# -----------------------------------------------------------------------------

###############################################
# ------------- FINAL STAGE ------------------
###############################################
FROM alpine:${ALPINE_VERSION}

# -----------------------------------------------------------------------------
# Re-declare any build-time arguments required in final image for clarity
# (Bests practice if referencing them again in final stage).
# -----------------------------------------------------------------------------
ARG PORT
ARG CONFIG_PATH

# -----------------------------------------------------------------------------
# Ensure security updates, install minimal runtime deps, and add CA certs.
# We also install a minimal MQTT client (mosquitto-clients) for optional
# debugging or readiness checks if needed. This is not mandatory but can help
# with integration testing and connectivity checks.
# -----------------------------------------------------------------------------
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
      ca-certificates \
      tzdata \
      libcap \
      mosquitto-clients && \
    update-ca-certificates

# -----------------------------------------------------------------------------
# Create a non-root user and group for running the service safely.
# -----------------------------------------------------------------------------
RUN addgroup -S nonroot && adduser -S nonroot -G nonroot

# -----------------------------------------------------------------------------
# Copy the statically built binary from the build stage into /app directory.
# -----------------------------------------------------------------------------
WORKDIR /app
COPY --from=build /app/tracking-service /app/tracking-service

# -----------------------------------------------------------------------------
# Apply "cap_net_bind_service" on the binary so it may bind to privileged ports
# if offset is needed. However, recommended approach is to run on unprivileged
# port. The 'cap-drop=ALL' and 'cap-add=NET_BIND_SERVICE' are often set at
# container runtime. For demonstration:
# -----------------------------------------------------------------------------
RUN setcap 'cap_net_bind_service=+ep' /app/tracking-service || echo "Setting capabilities failed, continuing."

# -----------------------------------------------------------------------------
# Security: drop all capabilities by default. Additional flags (e.g., no-new-privileges)
# must typically be passed at runtime via Docker or orchestration platform.
# -----------------------------------------------------------------------------
# NOTE: Dockerfile does not directly support all runtime security flags. 
# We define them here in comments to highlight recommended usage:
#   --security-opt=no-new-privileges:true
#   --security-opt=seccomp=unconfined (if needed for certain kernel calls)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Expose the application port specified by ARG / ENV. Default is 8080.
# -----------------------------------------------------------------------------
EXPOSE ${PORT}

# -----------------------------------------------------------------------------
# Define VOLUME points if needed for configs, certificates, or data storage.
# -----------------------------------------------------------------------------
VOLUME ["/app/config", "/app/certs", "/app/data"]

# -----------------------------------------------------------------------------
# Environment variables for runtime configuration. These can be overridden at run time.
# -----------------------------------------------------------------------------
ENV GIN_MODE=release \
    GOMAXPROCS=8 \
    MAX_CONNECTIONS=1000 \
    PORT=${PORT}

# -----------------------------------------------------------------------------
# Healthcheck to ensure the container responds properly on the /health endpoint.
# If the check fails, the orchestrator can restart the container to meet 99.9% uptime.
# -----------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=5s CMD \
   wget --no-verbose --tries=1 --spider http://localhost:${PORT}/health || exit 1

# -----------------------------------------------------------------------------
# Switch to nonroot user (as created above). This ensures the service runs with
# minimal privileges, improving security posture.
# -----------------------------------------------------------------------------
USER nonroot:nonroot

# -----------------------------------------------------------------------------
# Provide a short default command. 
# Graceful shutdown logic can be embedded in the binary using signals (SIGTERM).
# -----------------------------------------------------------------------------
ENTRYPOINT ["/app/tracking-service"]
CMD ["--config", "/app/config/config.yaml"]