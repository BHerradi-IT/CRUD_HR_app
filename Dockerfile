FROM python:3.11

WORKDIR /app

COPY backend/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV DATABASE_URL=postgresql://hr_app_user:LocalPostgres12345!@postgres:5432/ytech_hr

CMD ["python", "backend/manage.py", "runserver", "0.0.0.0:8000"]
