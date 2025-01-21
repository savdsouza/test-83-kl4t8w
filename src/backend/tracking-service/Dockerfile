################################################################################
# Multi-stage Dockerfile for the Go-based Tracking Service
# -------------------------------------------------------------------------------
# This Dockerfile builds and runs a production-ready container for the real-time
# dog walking tracking service. It addresses:
#  - Real-time Location Tracking (Go microservice, geofencing, route optimization)
#  - 99.9% Uptime Requirement (containerized deployment on minimal base image)
#  - Container Security (multi-stage builds, non-root user, minimized attack surface)
#
# References:
#  - go.mod (module: github.com/dogwalking/tracking-service, go version: 1.21)
#  - cmd/server/main.go (main entry point)
#  - External base images: golang:1.21-alpine, alpine:3.18
################################################################################

##############################
# Build Stage
##############################
FROM golang:1.21-alpine AS builder

# ------------------------------------------------------------------------------
# Environment variables for controlling the Go build:
#   GO111MODULE=on    -> Use Go Modules
#   CGO_ENABLED=0     -> Disable CGO to produce a statically linked binary
#   GOOS=linux        -> Target OS is Linux
#   GOARCH=amd64      -> Target architecture is x86_64
# ------------------------------------------------------------------------------
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

# ------------------------------------------------------------------------------
# Install build dependencies:
#   git             -> Required by Go modules for certain dependencies
#   make,gcc,libc-dev -> Build tools and compilers needed to build the Go binary
#   ca-certificates -> Trusted CA certificates for secure package downloads
#   binutils        -> Provides 'strip' for removing debug symbols
# ------------------------------------------------------------------------------
RUN apk add --no-cache \
    git \
    make \
    gcc \
    libc-dev \
    ca-certificates \
    binutils

# ------------------------------------------------------------------------------
# Set the working directory to /app inside the builder container.
# This is where all build commands will run.
# ------------------------------------------------------------------------------
WORKDIR /app

# ------------------------------------------------------------------------------
# Copy go.mod and (optionally) go.sum for dependency resolution.
# This ensures that dependencies are downloaded and cached prior to copying
# the entire source, which helps optimize Docker layer caching.
# ------------------------------------------------------------------------------
COPY go.mod ./
# If go.sum exists in your repository, uncomment the line below:
# COPY go.sum ./

# ------------------------------------------------------------------------------
# Download and verify Go module dependencies.
# Using 'go mod download' to retrieve all modules listed in go.mod.
# ------------------------------------------------------------------------------
RUN go mod download

# ------------------------------------------------------------------------------
# Copy the entire source code into the builder container.
# Adjust paths as necessary if you keep code outside '.' or have a specific structure.
# This includes: cmd/server/main.go, internal/*, etc.
# ------------------------------------------------------------------------------
COPY . .

# ------------------------------------------------------------------------------
# (Optional) Perform code or security checks before building (e.g., 'go vet').
# Demonstrating a basic code vet here:
# ------------------------------------------------------------------------------
RUN go vet ./...

# ------------------------------------------------------------------------------
# Build the final executable with security and optimization flags:
#  -trimpath          -> Remove all file system paths from the compiled binary
#  -ldflags="-s -w"   -> Strip debug information (smaller binary)
#  -extldflags='-static' -> Enable fully static linking, no external deps
# This produces an optimized binary named 'tracking-service' in /app.
# ------------------------------------------------------------------------------
RUN go build -trimpath -ldflags="-s -w -extldflags '-static'" -o tracking-service ./cmd/server

# ------------------------------------------------------------------------------
# Strip debug symbols from the binary for additional security and size reduction.
# The 'strip' command is provided by binutils (installed above).
# ------------------------------------------------------------------------------
RUN strip tracking-service

##############################
# Runtime Stage
##############################
FROM alpine:3.18

# ------------------------------------------------------------------------------
# Install only minimal runtime dependencies:
#   ca-certificates -> For SSL certificate trust
#   (No shell or extra packages to reduce attack surface)
# Update the certificate store to ensure all CA certs are recognized.
# ------------------------------------------------------------------------------
RUN apk add --no-cache ca-certificates && update-ca-certificates

# ------------------------------------------------------------------------------
# Add a dedicated non-root user and group for running the service inside the container,
# enhancing security and adhering to least-privileged principles.
# ------------------------------------------------------------------------------
RUN addgroup -S nonroot && adduser -S nonroot -G nonroot

# ------------------------------------------------------------------------------
# Apply Open Container Initiative (OCI) labels for metadata, provenance, and licensing.
# These labels help track container origin, version, and other relevant details.
# ------------------------------------------------------------------------------
LABEL maintainer="DogWalking DevOps Team" \
      version="1.0.0" \
      security.scan-date="${BUILD_DATE}" \
      org.opencontainers.image.source="github.com/dogwalking/tracking-service" \
      org.opencontainers.image.description="Dog Walking Tracking Service" \
      org.opencontainers.image.licenses="Proprietary"

# ------------------------------------------------------------------------------
# Set environment variables that may be relevant during runtime.
# CGO_ENABLED=0 ensures no dynamic linking. Typically, we only need the binary now,
# but we keep consistent environment settings if debugging or extended checks occur.
# ------------------------------------------------------------------------------
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

# ------------------------------------------------------------------------------
# Define a working directory in the final container for the service.
# We'll place the tracking-service binary here and run it.
# ------------------------------------------------------------------------------
WORKDIR /app

# ------------------------------------------------------------------------------
# Copy the final optimized and stripped binary from the builder stage to this stage.
# We also set ownership to the nonroot user for security.
# ------------------------------------------------------------------------------
COPY --from=builder /app/tracking-service /app/tracking-service
RUN chown nonroot:nonroot /app/tracking-service && chmod 0755 /app/tracking-service

# ------------------------------------------------------------------------------
# Switch to the nonroot user to enforce least privilege at runtime.
# ------------------------------------------------------------------------------
USER nonroot

# ------------------------------------------------------------------------------
# Expose port 8080 as documented in the service. This port is used to serve HTTP
# traffic, including health checks (/health) and metrics (/metrics).
# ------------------------------------------------------------------------------
EXPOSE 8080

# ------------------------------------------------------------------------------
# Configure a Health Check to verify that the tracking service is running and healthy.
# The service must respond to /health with a success code; otherwise, container orchestration
# (Kubernetes, Docker swarm, etc.) marks it unhealthy and can restart it.
#   --interval=30s    -> Time between health checks
#   --timeout=5s      -> Time before deciding the service is unresponsive
#   --start-period=5s -> Grace period after container starts
#   --retries=3       -> Number of consecutive failures before marking container unhealthy
# ------------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# ------------------------------------------------------------------------------
# The container entrypoint is set to run the tracking-service binary.
# We do not wrap it in a shell script to reduce overhead and simplify control.
# ------------------------------------------------------------------------------
ENTRYPOINT ["./tracking-service"]