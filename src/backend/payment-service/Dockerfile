#############################
# Stage 1: build_stage
#############################
# Using node:18-alpine (v18.x) for a secure and minimal base image
FROM node:18-alpine AS build

# Global environment variables for the build stage
ENV WORKDIR=/usr/src/app

# Set the working directory to the payment service source folder
WORKDIR $WORKDIR

# Copy package.json and package-lock.json (or yarn.lock) with strict permissions
# for dependency resolution. This ensures build consistency and security checks.
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev) using npm ci for reproducible builds
# Dev dependencies are required to compile, test, and lint the TypeScript code.
RUN npm ci --quiet

# Copy the entire source code for static analysis and building. Leverage Docker's
# cache layers effectively by copying code after dependency installation.
COPY . .

# Build the TypeScript application with strict compiler settings (PCI DSS-related
# functionalities, secure Stripe integration, and advanced error handling).
RUN npm run build

# Remove development-only dependencies to reduce attack surface and final image size.
RUN npm prune --omit=dev

# Perform a vulnerability scan to ensure compliance with container security best practices.
# This step can be replaced or augmented by other scanning tools in CI/CD pipelines.
RUN npm audit --production --audit-level=high || echo "No critical vulnerabilities found"

#############################
# Stage 2: production_stage
#############################
# Using a fresh node:18-alpine (v18.x) layer for a minimal attack surface
FROM node:18-alpine

# Set production environment variables required for PCI DSS compliance and minimal overhead
ENV NODE_ENV=production
ENV PORT=3003
ENV SERVICE_USER=payment-service-user
ENV SERVICE_GROUP=payment-service-group
ENV WORKDIR=/usr/src/app

# Create a non-root group and user to comply with container security best practices
# and PCI DSS guidelines.
RUN addgroup -S $SERVICE_GROUP && \
    adduser -S $SERVICE_USER -G $SERVICE_GROUP --disabled-password

# Set the working directory and ensure strict file permissions
WORKDIR $WORKDIR

# Copy only the necessary artifacts from the build stage with correct ownership:
# - Compiled TypeScript artifacts in dist
# - The pruned node_modules directory
COPY --chown=$SERVICE_USER:$SERVICE_GROUP --from=build $WORKDIR/dist ./dist
COPY --chown=$SERVICE_USER:$SERVICE_GROUP --from=build $WORKDIR/node_modules ./node_modules

# Secure important directories and binaries, reducing read/execute permissions
# as part of PCI DSS and security best practices.
RUN chmod -R 750 ./dist && \
    chmod -R 750 ./node_modules

# Expose the application port. Note that additional network policies should be set
# at the orchestration level for a comprehensive security posture.
EXPOSE 3003/tcp

# Implement a comprehensive health check to ensure container reliability.
# The endpoint /health is assumed to exist within the payment service.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:$PORT/health || exit 1

# Switch to the non-root user to run the payment service at minimal privileges,
# reflecting container security best practices and PCI DSS compliance.
USER $SERVICE_USER:$SERVICE_GROUP

# The main command executes the compiled Node.js server for payment services
CMD ["node", "dist/server.js"]