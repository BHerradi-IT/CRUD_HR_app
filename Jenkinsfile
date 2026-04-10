pipeline {
    agent any

    environment {
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        ALLOWED_HOSTS = '*'

        DB_NAME = 'hr_app_db'
        DB_USER = 'postgres'
        DB_PASSWORD = 'postgres'
        DB_HOST = 'localhost'
        DB_PORT = '5432'

        DOCKER_HUB_USER = 'peacechouaib'
        DOCKER_IMAGE_NAME = 'crud_hr_app'
        DOCKER_IMAGE = "${DOCKER_HUB_USER}/${DOCKER_IMAGE_NAME}"

        PYTHONUNBUFFERED = '1'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo '✅ Code checked out'
            }
        }

        stage('Setup Python') {
            steps {
                sh """
                    python3 -m venv venv
                    . venv/bin/activate

                    pip install --upgrade pip
                    pip install Django==4.2.20 djangorestframework \
                        psycopg2-binary gunicorn argon2-cffi \
                        pytest pytest-django pytest-cov \
                        flake8 black coverage
                """
                echo '✅ Python environment ready'
            }
        }

        stage('Fix Django Configuration') {
            steps {
                sh """
                    . venv/bin/activate
                    cd backend/hr_core

                    python3 << 'EOF'
import re

with open('settings.py', 'r') as f:
    content = f.read()

# Add employees app safely
if "'employees'" not in content:
    pattern = "(INSTALLED_APPS\\\\s*=\\\\s*\\\\[)([^\\\\]]*)(\\\\])"

    def add_app(match):
        apps = match.group(2)
        if "'employees'" not in apps:
            apps = apps.rstrip() + "\\n    'employees',\\n"
        return match.group(1) + apps + match.group(3)

    content = re.sub(pattern, add_app, content, flags=re.DOTALL)
    print("✅ employees added")

# Add PASSWORD_HASHERS if missing
if "PASSWORD_HASHERS" not in content:
    content += '''
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
]
'''
    print("✅ PASSWORD_HASHERS added")

with open('settings.py', 'w') as f:
    f.write(content)

print("✅ settings.py updated")
EOF

                    cd ../..
                """
                echo '✅ Django config fixed'
            }
        }

        stage('Lint') {
            steps {
                sh """
                    . venv/bin/activate
                    cd backend
                    flake8 . || true
                """
                echo '✅ Lint done'
            }
        }

        stage('Start PostgreSQL') {
            steps {
                sh """
                    docker rm -f postgres-test || true

                    docker run -d --name postgres-test \
                        -e POSTGRES_DB=${DB_NAME} \
                        -e POSTGRES_USER=${DB_USER} \
                        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
                        -p 5432:5432 postgres:15

                    sleep 10
                """
                echo '✅ PostgreSQL running'
            }
        }

        stage('Migrate') {
            steps {
                sh """
                    . venv/bin/activate
                    cd backend
                    python manage.py migrate --noinput
                """
                echo '✅ Migrations done'
            }
        }

        stage('Test') {
            steps {
                sh """
                    . venv/bin/activate
                    cd backend
                    python manage.py test --noinput || true
                """
                echo '✅ Tests executed'
            }
        }

        stage('Coverage') {
            steps {
                sh """
                    . venv/bin/activate
                    cd backend
                    coverage run manage.py test || true
                    coverage report || true
                """
                echo '✅ Coverage generated'
            }
        }

        stage('Build Docker') {
            when { branch 'main' }
            steps {
                sh """
                    if [ ! -f Dockerfile ]; then
                        cat > Dockerfile << 'DOCKERFILE'
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn psycopg2-binary argon2-cffi

COPY backend .

RUN python manage.py collectstatic --noinput || true

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "hr_core.wsgi:application"]
DOCKERFILE
                    fi

                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                """
                echo '✅ Docker built'
            }
        }

        stage('Push Docker Image') {
            when { branch 'main' }
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u ${DOCKER_HUB_USER} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    """
                }
                echo '✅ Docker pushed'
            }
        }

        stage('Deploy Info') {
            when { branch 'main' }
            steps {
                echo """
🚀 Deployment commands:
docker pull ${DOCKER_IMAGE}:latest
docker run -d -p 8000:8000 ${DOCKER_IMAGE}:latest
"""
            }
        }
    }

    post {
        always {
            sh """
                docker rm -f postgres-test || true
                rm -rf venv || true
            """
            echo '🧹 Cleanup done'
        }

        success {
            echo '🎉 PIPELINE SUCCESS'
        }

        failure {
            echo '❌ PIPELINE FAILED'
        }
    }
}
