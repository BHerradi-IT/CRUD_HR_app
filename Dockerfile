FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn psycopg2-binary argon2-cffi

COPY backend /app/backend
COPY config /app/config

ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=hr_core.settings

WORKDIR /app/backend
RUN python manage.py collectstatic --noinput || true

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2", "hr_core.wsgi:application"]
