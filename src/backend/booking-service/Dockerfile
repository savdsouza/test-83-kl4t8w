################################################################################
#                          MULTI-STAGE DOCKERFILE                               #
#             Booking Service (Java/Spring Boot) - Production Ready            #
################################################################################

###############################################################################
#                           STAGE 1 - BUILDER                                 #
###############################################################################
# Using eclipse-temurin:17-jdk-alpine as the secure JDK base image (version 17)
# for compiling the Java application. Referenced from pom.xml <java.version>17</java.version>.
FROM eclipse-temurin:17-jdk-alpine AS builder

# ---------------------------------------------------------------------------
# Install necessary build tools: curl, wget, git, ca-certificates, maven, bash
# ---------------------------------------------------------------------------
RUN apk update && apk add --no-cache \
    curl \
    wget \
    git \
    bash \
    ca-certificates \
    openssl \
    tzdata \
    maven

# ---------------------------------------------------------------------------
# Create a dedicated directory for the Maven build process
# ---------------------------------------------------------------------------
WORKDIR /home/app/maven

# ---------------------------------------------------------------------------
# Copy the Maven configuration (pom.xml) for dependency resolution
# Enable layer caching by copying pom.xml separately before source code
# ---------------------------------------------------------------------------
COPY pom.xml ./

# ---------------------------------------------------------------------------
# Pre-fetch all Maven dependencies to optimize subsequent builds
# ---------------------------------------------------------------------------
RUN mvn -B dependency:go-offline

# ---------------------------------------------------------------------------
# Copy the source code and set proper permissions for secure builds
# ---------------------------------------------------------------------------
COPY src ./src
RUN chown -R root:root ./src

# ---------------------------------------------------------------------------
# (Optional) Security scan on dependencies or project files
# Example with Trivy (uncomment if the scanner is available in the build image)
# RUN apk add --no-cache trivy && trivy fs --exit-code 1 --severity HIGH,CRITICAL .
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Build the Spring Boot application with layered jars enabled
# -DskipTests is used for production builds; for improved QA, remove if tests are required.
# ---------------------------------------------------------------------------
RUN mvn -B -DskipTests=true clean package spring-boot:repackage

# ---------------------------------------------------------------------------
# Extract the layered JAR contents for optimized Docker layer caching.
# This approach creates separate directories for dependencies and application.
# ---------------------------------------------------------------------------
RUN mkdir -p build/layers && \
    java -Djarmode=layertools -jar target/*.jar extract --destination build/layers

###############################################################################
#                         STAGE 2 - RUNTIME (HARDENED)                         #
###############################################################################
# Using eclipse-temurin:17-jre-alpine as the minimal Java runtime for production
FROM eclipse-temurin:17-jre-alpine AS runtime

# ---------------------------------------------------------------------------
# Define Container Labels (Metadata)
# These labels include version info, security scan date, etc.
# ---------------------------------------------------------------------------
LABEL maintainer="DogWalking DevOps Team" \
      version="1.0.0" \
      service="booking-service" \
      environment="production" \
      security.scan-date="{{BUILD_DATE}}" \
      build.git-commit="{{GIT_COMMIT}}"

# ---------------------------------------------------------------------------
# Create a non-root user and group with specific UID/GID for security
# ---------------------------------------------------------------------------
ARG APP_USER=appuser
ARG APP_GROUP=appgroup
ARG APP_UID=1000
ARG APP_GID=1000

RUN addgroup --gid ${APP_GID} ${APP_GROUP} && \
    adduser --disabled-password --gecos "" --home /app --uid ${APP_UID} --gid ${APP_GID} ${APP_USER}

# ---------------------------------------------------------------------------
# Set up directories, ensuring restricted permissions and ownership
# /tmp for temporary storage, /app for application, /app/logs for logs
# ---------------------------------------------------------------------------
RUN mkdir -p /app/logs && \
    mkdir -p /tmp && \
    chown -R ${APP_USER}:${APP_GROUP} /app && \
    chown -R ${APP_USER}:${APP_GROUP} /tmp

# ---------------------------------------------------------------------------
# Copy the layered application artifacts from the builder stage.
# The layering approach allows Docker to cache different parts (deps, resources).
# ---------------------------------------------------------------------------
WORKDIR /app

# Dependencies
COPY --chown=${APP_USER}:${APP_GROUP} --from=builder /home/app/maven/build/layers/dependencies/ ./
COPY --chown=${APP_USER}:${APP_GROUP} --from=builder /home/app/maven/build/layers/snapshot-dependencies/ ./

# Resources
COPY --chown=${APP_USER}:${APP_GROUP} --from=builder /home/app/maven/build/layers/resources/ ./

# Application (classes)
COPY --chown=${APP_USER}:${APP_GROUP} --from=builder /home/app/maven/build/layers/application/ ./

# ---------------------------------------------------------------------------
# Set the environment variables to align with production best practices
# ---------------------------------------------------------------------------
ENV SERVER_PORT=8082
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -XX:+UseContainerSupport -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError"
ENV SPRING_PROFILES_ACTIVE=production
ENV TZ=UTC

# ---------------------------------------------------------------------------
# Expose the application port (SERVER_PORT) over TCP
# ---------------------------------------------------------------------------
EXPOSE 8082

# ---------------------------------------------------------------------------
# Declare volumes for ephemeral data: /tmp and /app/logs
# Allows external mounting if necessary.
# ---------------------------------------------------------------------------
VOLUME ["/tmp", "/app/logs"]

# ---------------------------------------------------------------------------
# Docker HEALTHCHECK to ensure the container is responsive
# Using the non-root user to run the healthcheck is a best practice.
# Retries 3x, 30s interval, 10s timeout, 40s start grace period
# ---------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 --user=${APP_USER} CMD \
    wget --no-verbose --tries=1 --spider http://localhost:${SERVER_PORT}/api/v1/bookings/actuator/health || exit 1

# ---------------------------------------------------------------------------
# Switch to non-root user for final runtime security
# ---------------------------------------------------------------------------
USER ${APP_USER}:${APP_GROUP}

# ---------------------------------------------------------------------------
# Additional Security Hardening (Optional):
#   - "docker run --cap-drop=ALL" to drop Linux capabilities
#   - "docker run --read-only" to enforce read-only root filesystem
#   - "docker run --security-opt=no-new-privileges"
#   - "docker run --security-opt seccomp=default"
# These are recommended at runtime for maximum security.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Entry point to run the Spring Boot application.
# Using shell form to allow environment variable expansion in $JAVA_OPTS.
# ---------------------------------------------------------------------------
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dserver.port=$SERVER_PORT -cp /app:/app/BOOT-INF/classes:/app/BOOT-INF/lib/* org.springframework.boot.loader.JarLauncher"]