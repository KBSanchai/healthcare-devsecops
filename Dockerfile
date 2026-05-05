# Stage 1: Build
FROM python:3.11-alpine AS builder
WORKDIR /build
RUN apk add --no-cache gcc musl-dev libffi-dev
COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Production
FROM python:3.11-alpine
RUN apk add --no-cache libffi curl && \
    rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 10001 -S appgroup && \
    adduser -S -u 10001 -G appgroup -H -D appuser

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY app/ .

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/home/appuser/.local/bin:$PATH"

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "30", "main:app"]
