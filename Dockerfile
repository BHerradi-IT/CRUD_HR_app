# Dockerfile
FROM python:3.10-slim as builder

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY backend/requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt
RUN pip install --user gunicorn psycopg2-binary argon2-cffi redis celery

# Final stage
FROM python:3.10-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python dependencies from builder
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY backend /app/backend
COPY config /app/config

# Set environment variables
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=hr_core.settings

WORKDIR /app/backend

# Collect static files
RUN python manage.py collectstatic --noinput || true

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl --fail http://localhost:8000/health/ || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2", "hr_core.wsgi:application"]
