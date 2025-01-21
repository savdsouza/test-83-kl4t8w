# ------------------------------------------------------------------------------
# Dockerfile for the Notification Service Container Image
# ------------------------------------------------------------------------------
# This Dockerfile implements a multi-stage build to create an optimized and
# secure container for the notification service, which handles multi-channel
# notifications (email, push, SMS) and meets the following requirements:
# 1) Multi-channel notifications in Python (FastAPI-based).
# 2) Emergency response notifications with fast startup (critical P0 <5min).
# 3) System availability of 99.9% through health checks and optimized config.
#
# We rely on python:3.11-slim (Debian Bullseye-based) to keep the image minimal
# and up to date with security patches. During the build stage, we install and
# compile any necessary dependencies to ensure our final image is lean.
#
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#                           STAGE 1: BUILDER
# ------------------------------------------------------------------------------
# python:3.11-slim (v3.11-slim) is used here for building dependencies
FROM python:3.11-slim AS builder

# ------------------------------------------------------------------------------
# Environment configuration for Python
# ------------------------------------------------------------------------------
# PYTHONUNBUFFERED = 1 ensures that Python does not buffer output,
# making logs visible in real-time within Docker.
# PYTHONDONTWRITEBYTECODE = 1 avoids writing .pyc files to disk.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# ------------------------------------------------------------------------------
# Update system packages and install required build dependencies
# ------------------------------------------------------------------------------
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    libffi-dev \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# Set up application directory inside the builder
# ------------------------------------------------------------------------------
WORKDIR /app

# ------------------------------------------------------------------------------
# Copy the Python dependencies file and install packages
# ------------------------------------------------------------------------------
# The following packages (with exact versions) are installed from requirements.txt:
# fastapi==0.95.0
# uvicorn[standard]==0.23.2
# firebase-admin==6.2.0
# aioapns==3.0.1
# aiosmtplib==2.0.1
# jinja2==3.1.2
# twilio==8.1.0
# pydantic==1.10.7
# tenacity[async]==8.2.3
# python-jose[cryptography]==3.3.0
# httpx==0.24.1
# prometheus-client==0.17.1
# sentry-sdk[fastapi]==1.28.1
COPY requirements.txt ./

# Upgrade pip to latest secure version and install dependencies without caching
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --upgrade -r requirements.txt

# ------------------------------------------------------------------------------
#                           STAGE 2: FINAL IMAGE
# ------------------------------------------------------------------------------
FROM python:3.11-slim

# ------------------------------------------------------------------------------
# Create a non-root user for running the notification service securely
# ------------------------------------------------------------------------------
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* && \
    groupadd -r notifier && useradd -r -g notifier notifier

# ------------------------------------------------------------------------------
# Define environment variables for the final container
# ------------------------------------------------------------------------------
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_HOME=/app \
    PORT=8000 \
    PROMETHEUS_MULTIPROC_DIR=/tmp/prometheus \
    NOTIFICATION_SERVICE_VERSION=1.0.0

# ------------------------------------------------------------------------------
# Set working directory, copy dependencies from the builder, and copy code
# ------------------------------------------------------------------------------
WORKDIR /app

# Copy installed site-packages from the builder stage to keep final image small
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy application source code to /app with correct ownership for the notifier user
COPY --chown=notifier:notifier . /app

# ------------------------------------------------------------------------------
# Expose the port used by the notification service
# ------------------------------------------------------------------------------
EXPOSE 8000

# ------------------------------------------------------------------------------
# Create volume for Prometheus multi-process metrics
# ------------------------------------------------------------------------------
VOLUME ["/tmp/prometheus"]

# ------------------------------------------------------------------------------
# Configure Docker HEALTHCHECK for enhanced monitoring and 99.9% uptime
# ------------------------------------------------------------------------------
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=20s \
  CMD curl -f http://localhost:8000/health || exit 1

# ------------------------------------------------------------------------------
# Switch to the non-root user for enhanced security
# ------------------------------------------------------------------------------
USER notifier

# ------------------------------------------------------------------------------
# Set the container entrypoint and default command:
# uvicorn with app:app from our FastAPI service, serving on port 8000 with 4 workers
# ------------------------------------------------------------------------------
ENTRYPOINT ["uvicorn"]
CMD ["app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]