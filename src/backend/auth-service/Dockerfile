###################################################################################################
# Stage: builder
# Description: Builds the authentication microservice, installs dependencies (including dev), 
#              compiles TypeScript to JavaScript, and prunes dev dependencies to prepare 
#              a minimized production-ready artifact.
###################################################################################################
FROM node:18-alpine AS builder
# node@18-alpine (third-party library version)

# Install necessary system packages for compiling native modules (e.g., bcrypt).
RUN apk add --no-cache python3 make g++

# Establish the working directory for the build process.
WORKDIR /app

# Copy package.json (and optionally lockfile if present) for dependency installation.
# This step ensures Docker can cache npm install layers when only source code changes.
COPY package.json ./

# Install all dependencies (including dev) to allow building TypeScript code.
RUN npm install

# Copy the TypeScript configuration file to enable compilation.
COPY tsconfig.json ./

# Copy the entire source code for the authentication service.
COPY src ./src

# Trigger the build process, compiling TypeScript into JavaScript within ./dist.
RUN npm run build

# Remove development-only dependencies to reduce the final image size and 
# enhance security by eliminating potential dev tools in production.
RUN npm prune --omit=dev


###################################################################################################
# Stage: production
# Description: Copies over only the necessary artifacts (production node_modules, 
#              compiled JavaScript dist, and package.json) into a fresh, minimal 
#              environment with a non-root user and security best practices enabled.
###################################################################################################
FROM node:18-alpine
# node@18-alpine (third-party library version)

# Create a non-root user (authuser) and group (authuser) for improved container security.
RUN addgroup -S authuser && adduser -S -G authuser authuser

# Establish the working directory for the final container runtime.
WORKDIR /app

# Copy the production-ready artifacts from the builder stage.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./

# Recursively set secure file permissions (755) on all container application files.
RUN chmod -R 755 /app

# Switch to the non-root user to follow security best practices.
USER authuser:authuser

# Define volumes for node_modules and dist, allowing external mounts if needed.
VOLUME ["/app/node_modules", "/app/dist"]

# Expose the authentication service port (default 3001) for container-to-host communication.
EXPOSE 3001

# Configure a health check to ensure the container remains responsive.
# Docker will periodically run this command to verify the service is healthy.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl --fail http://localhost:3001/health || exit 1

# Set necessary environment variables for production operation.
ENV NODE_ENV=production \
    PORT=3001 \
    USER=authuser

# For added security, consider running the container with:
#   docker run --security-opt no-new-privileges:true
# or in Docker Compose:
#   security_opt:
#     - no-new-privileges:true
# This ensures the container cannot escalate privileges.

# Use the official start script from package.json to launch the authentication service.
CMD ["npm", "run", "start"]