# Dockerfile for Flask Application
# Multi-stage build for optimization

# Stage 1: Build stage
FROM python:3.9-slim as builder

WORKDIR /app

# Copy requirements first (better caching)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.9-slim

LABEL maintainer="yashwinkoila@gmail.com"
LABEL description="DevOps Learning Flask Application"

WORKDIR /app

# Copy only necessary files from builder stage
COPY --from=builder /root/.local /root/.local
COPY app.py .

# Make sure scripts in .local are usable
ENV PATH=/root/.local/bin:$PATH

# Expose port
EXPOSE 5000

# Set environment variables
ENV FLASK_APP=app.py
ENV FLASK_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

# Command to run when container starts
CMD ["python", "app.py"]