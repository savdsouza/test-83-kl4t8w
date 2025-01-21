############################################################
# Multi-stage Dockerfile for the Booking Service
# Addressing Containerization (Tech Specs §8.3.1),
# Service Architecture (Tech Specs §2.1), and
# Security Requirements (Tech Specs §7.1)
############################################################

############################################################
# 1. BUILD STAGE: "builder"
#    Using eclipse-temurin:17-jdk-alpine (Java 17)
#    Purpose:
#      - Dependency caching
#      - Maven build for Spring Boot
#      - Produce an optimized JAR
############################################################

# Using eclipse-temurin 17-jdk-alpine for the build stage (lightweight JDK)
FROM eclipse-temurin:17-jdk-alpine AS builder

# Set working directory for build operations
WORKDIR /app

# Copy only the Maven configuration (pom.xml) to leverage dependency caching
COPY pom.xml .

# Pre-fetch project dependencies to optimize subsequent builds
# (Corresponds to "RUN mvn dependency:go-offline" in spec)
RUN apk add --no-cache maven=3.9.3-r0 && mvn dependency:go-offline

# Copy the complete source code, including resources and configurations
COPY src ./src

# Build the Spring Boot application in an optimized manner with tests skipped
RUN mvn clean package -DskipTests -Dmaven.test.skip=true

############################################################
# 2. RUNTIME STAGE: "runtime"
#    Using eclipse-temurin:17-jre-alpine (Java 17)
#    Purpose:
#      - Minimal final image with JRE
#      - Non-root user for security
#      - Health checks and resource limits
#      - Monitoring readiness with Spring Actuator
############################################################

# Using eclipse-temurin 17-jre-alpine for the runtime stage (minimal JRE)
FROM eclipse-temurin:17-jre-alpine AS runtime

# Set working directory for runtime
WORKDIR /app

# Copy the built artifact (JAR) from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Create a non-root user and group to satisfy security best practices
RUN addgroup -S spring && adduser -S spring -G spring

# Adjust ownership of /app to the newly created non-root user
RUN chown spring:spring /app

# Switch to non-root user
USER spring:spring

# Set JVM options as per specification (Tech Specs §8.3.1 + JSON "globals")
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0 -XX:+UseG1GC"

# Expose the service port (8082) for the Booking Service
EXPOSE 8082

# Configure a comprehensive HEALTHCHECK using Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8082/actuator/health || exit 1

# Entry point to run the JAR with all defined JAVA_OPTS
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]