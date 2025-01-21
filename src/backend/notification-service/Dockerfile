##############################################
# MULTI-STAGE DOCKERFILE FOR NOTIFICATION SERVICE
# Handles email, SMS, and push notifications
# Includes emergency response protocols
##############################################

##############################################
# STAGE 1: BUILDER
# Purpose: Compile and prepare Python dependencies
##############################################
FROM python:3.11-slim AS builder  # python:3.11-slim (Python 3.11)
LABEL stage="builder"

# -----------------------------------------------------------------------------
# Set environment variables to ensure consistent behavior during build
# -----------------------------------------------------------------------------
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
ENV WORKDIR=/app

# -----------------------------------------------------------------------------
# Install system-level build dependencies required for Python packages
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential=12.9 \
    gcc=4:12.2.0-1 \
    libffi-dev=3.4.2-4 \
    curl=7.85.0-1 \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Create application directory
# -----------------------------------------------------------------------------
WORKDIR /app

# -----------------------------------------------------------------------------
# Copy Python dependency manifest (requirements.txt)
# -----------------------------------------------------------------------------
COPY requirements.txt /app/requirements.txt

# -----------------------------------------------------------------------------
# Upgrade pip and install Python packages
# Note: uvicorn[standard]==0.23.2 is installed as defined in requirements.txt
# -----------------------------------------------------------------------------
RUN pip install --no-cache-dir --upgrade pip==23.2.1 && \
    pip install --no-cache-dir -r /app/requirements.txt

# -----------------------------------------------------------------------------
# Remove build artifacts to reduce image size
# -----------------------------------------------------------------------------
RUN apt-get remove -y build-essential gcc libffi-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

##############################################
# STAGE 2: FINAL
# Purpose: Create a minimal production image
##############################################
FROM python:3.11-slim AS final  # python:3.11-slim (Python 3.11)

# -----------------------------------------------------------------------------
# LABELS for container metadata
# -----------------------------------------------------------------------------
LABEL maintainer="DogWalking DevOps Team" \
      version="1.0.0" \
      description="Notification Service Container" \
      security.scan-required="true"

# -----------------------------------------------------------------------------
# Environment variables for consistent runtime behavior
# -----------------------------------------------------------------------------
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
ENV WORKDIR=/app
ENV APP_USER=appuser
ENV APP_GROUP=appgroup

# -----------------------------------------------------------------------------
# Create non-root user and group for security
# -----------------------------------------------------------------------------
RUN groupadd --gid 1000 "${APP_GROUP}" && \
    useradd --uid 1000 --gid "${APP_GROUP}" --no-log-init -m "${APP_USER}"

# -----------------------------------------------------------------------------
# Install curl for healthcheck usage
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl=7.85.0-1 && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Set the working directory
# -----------------------------------------------------------------------------
WORKDIR /app

# -----------------------------------------------------------------------------
# Copy site-packages from builder stage to final stage
# Ensures all dependencies are available in the runtime image
# -----------------------------------------------------------------------------
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# -----------------------------------------------------------------------------
# Copy application code into the container
# -----------------------------------------------------------------------------
COPY . /app

# -----------------------------------------------------------------------------
# Set directory permissions for enhanced security
#  - /app => 755
#  - /app/config => 750
#  - /app/logs => 770
# -----------------------------------------------------------------------------
RUN chmod 755 /app && \
    mkdir -p /app/config && chmod 750 /app/config && \
    mkdir -p /app/logs && chmod 770 /app/logs

# -----------------------------------------------------------------------------
# Configure volumes for logs and configuration
# -----------------------------------------------------------------------------
VOLUME ["/app/logs", "/app/config"]

# -----------------------------------------------------------------------------
# Expose the service port
# -----------------------------------------------------------------------------
EXPOSE 8000

# -----------------------------------------------------------------------------
# HEALTHCHECK to verify that the application is responsive
#  - Interval: 30 seconds
#  - Timeout: 10 seconds
#  - Retries: 3
#  - Start period: 40 seconds
# -----------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
  CMD curl -f http://localhost:8000/health || exit 1

# -----------------------------------------------------------------------------
# Switch to non-root user
# -----------------------------------------------------------------------------
USER ${APP_USER}:${APP_GROUP}

# -----------------------------------------------------------------------------
# ENTRYPOINT for launching the FastAPI application using Uvicorn
# -----------------------------------------------------------------------------
ENTRYPOINT ["uvicorn", "src.app:app", "--host", "0.0.0.0", "--port", "8000"]