###################################################################################################
# Multi-stage Dockerfile for API Gateway
# -----------------------------------------------------------------------------------------------
# This Dockerfile builds and configures a secure, production-ready API Gateway service container
# with comprehensive security hardening, monitoring, and performance optimizations. It addresses:
#   - Advanced request routing, validation, and rate limiting for the API Gateway
#   - Stringent uptime requirement (99.9% availability) through efficient Node.js configuration,
#     container health checks, and resource constraints
#   - Comprehensive container security via non-root execution, strict file permissions, security
#     scanning, read-only file system recommendations, and minimized capabilities
###################################################################################################

########################################
# 1. Builder Stage
########################################
FROM node:18-alpine AS builder

# --------------------------------------------------------------------------
# Stage Metadata
# --------------------------------------------------------------------------
LABEL stage="builder" \
      maintainer="DogWalkingPlatform <support@dogwalking.example>" \
      description="Builder stage for compiling TypeScript and optimizing dependencies in a secure manner"

# --------------------------------------------------------------------------
# Install Build Essentials and Security Tools
# --------------------------------------------------------------------------
RUN apk update && apk add --no-cache \
    python3 \
    make \
    g++ \
    openssl \
    git \
    bash

# --------------------------------------------------------------------------
# Create and Set the Working Directory
# --------------------------------------------------------------------------
WORKDIR /app

# --------------------------------------------------------------------------
# Copy Package Files with Checksum Verification (stub approach)
# --------------------------------------------------------------------------
# In practice, one might verify checksums or GPG signatures for package files.
COPY package*.json ./

# --------------------------------------------------------------------------
# Install Dependencies with Strict Security Audit
# --------------------------------------------------------------------------
# Using npm scripts security:audit and security:scan (from package.json) to perform audits.
RUN npm ci --no-optional && \
    npm run security:audit && \
    npm run security:scan

# --------------------------------------------------------------------------
# Copy Source Code with Integrity Checks (stub approach)
# --------------------------------------------------------------------------
COPY . /app

# --------------------------------------------------------------------------
# Build TypeScript with Optimizations
# --------------------------------------------------------------------------
RUN npm run build

# --------------------------------------------------------------------------
# Prune Development Dependencies
# --------------------------------------------------------------------------
RUN npm prune --production

# --------------------------------------------------------------------------
# Compress node_modules for Production
# --------------------------------------------------------------------------
RUN tar -czf node_modules_prod.tgz node_modules


########################################
# 2. Production Stage
########################################
FROM node:18-alpine AS production

# --------------------------------------------------------------------------
# Stage Metadata
# --------------------------------------------------------------------------
LABEL maintainer="DogWalkingPlatform <support@dogwalking.example>" \
      description="Production stage for API Gateway container with security hardening, monitoring, and performance optimizations"

# --------------------------------------------------------------------------
# Create Non-root User with Specific UID/GID for Security
# --------------------------------------------------------------------------
RUN addgroup -g 1000 node && adduser -D -u 1000 -G node node

# --------------------------------------------------------------------------
# Set the Working Directory
# --------------------------------------------------------------------------
WORKDIR /app

# --------------------------------------------------------------------------
# Copy Built Artifacts and Production Dependencies from Builder
# --------------------------------------------------------------------------
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules_prod.tgz ./node_modules_prod.tgz

# --------------------------------------------------------------------------
# Extract node_modules Archive
# --------------------------------------------------------------------------
RUN tar -xzf node_modules_prod.tgz && rm -f node_modules_prod.tgz

# --------------------------------------------------------------------------
# Set Environment Variables
# --------------------------------------------------------------------------
# NODE_ENV: ensures the application runs in production mode
# PORT: the main port for the API Gateway
# API_VERSION: version tag used within gateway routes
# NODE_OPTIONS: configure memory constraints
# PINO_LOG_LEVEL: logging level
# GRACEFUL_SHUTDOWN_TIMEOUT: time (seconds) for graceful shutdown
ENV NODE_ENV="production" \
    PORT="3000" \
    API_VERSION="v1" \
    NODE_OPTIONS="--max-old-space-size=2048" \
    PINO_LOG_LEVEL="info" \
    GRACEFUL_SHUTDOWN_TIMEOUT="30"

# --------------------------------------------------------------------------
# Set Strict File Permissions
# --------------------------------------------------------------------------
# App files (755), config files (644), logs (644 if created). The directory must allow executes.
RUN mkdir -p /app/logs && \
    chmod 755 /app/logs && \
    chmod -R 755 /app/dist

# --------------------------------------------------------------------------
# Configure Security Policies (Capabilities, etc.)
# --------------------------------------------------------------------------
# 1) Install libcap to manage capabilities
# 2) Drop all, but add NET_BIND_SERVICE so that a non-root user can bind privileged ports if needed
RUN apk add --no-cache libcap && \
    setcap 'cap_net_bind_service=+ep' "$(which node)"

# --------------------------------------------------------------------------
# Expose Necessary Ports
# --------------------------------------------------------------------------
# 1) 3000: Main API Gateway HTTP port
# 2) 9091: Health check / metrics endpoint (if separate or utilized)
EXPOSE 3000
EXPOSE 9091

# --------------------------------------------------------------------------
# Declare Volumes for Logs, Node Modules, and Temporary Storage
# --------------------------------------------------------------------------
#  - /app/logs: location for structured logs
#  - /app/node_modules: installed packages
#  - /tmp: ephemeral temp storage recommended as tmpfs for read-only root
VOLUME ["/app/logs", "/app/node_modules", "/tmp"]

# --------------------------------------------------------------------------
# Health Check Configuration
# --------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s CMD \
  curl -f http://localhost:3000/health || exit 1

# --------------------------------------------------------------------------
# Enable Resource Constraints (documentation reference)
# --------------------------------------------------------------------------
# By default, Docker doesn't enforce these limits unless specified at runtime.
# For reference:
#  - Memory: 2G (set in orchestrator or with --memory=2g)
#  - CPU: 1.0 (set in orchestrator or with --cpus=1)
#  - pids: 50 (container-level process limits in orchestrator)
#  - nofile: 1000 (file descriptor limit in orchestrator)

# --------------------------------------------------------------------------
# Additional Security Options (documentation reference)
# --------------------------------------------------------------------------
# To fully enforce read-only root, no-new-privileges, and seccomp=unconfined, configure at runtime:
#  docker run --read-only --tmpfs /tmp --tmpfs /run \
#    --security-opt=no-new-privileges \
#    --security-opt seccomp=unconfined \
#    --cap-drop=ALL --cap-add=NET_BIND_SERVICE ...
# or in an equivalent container orchestration YAML.

# --------------------------------------------------------------------------
# Switch to Non-root User
# --------------------------------------------------------------------------
USER node

# --------------------------------------------------------------------------
# Configure Graceful Shutdown and Start the API Gateway
# --------------------------------------------------------------------------
CMD [ "node", "dist/server.js" ]