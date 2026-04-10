pipeline {
    agent any

    environment {
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        ALLOWED_HOSTS = 'localhost,127.0.0.1'

        DB_NAME = 'hr_app_db'
        DB_USER = 'postgres'
        DB_PASSWORD = 'postgres'
        DB_HOST = 'localhost'
        DB_PORT = '5432'

        PYTHONUNBUFFERED = '1'
        
        // Docker Hub configuration
        DOCKER_HUB_USER = 'peacechouaib'
        DOCKER_IMAGE_NAME = 'crud_hr_app'
        DOCKER_IMAGE = "${DOCKER_HUB_USER}/${DOCKER_IMAGE_NAME}"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo '✅ Code checked out successfully'
            }
        }

        stage('Setup Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install wheel
                    pip install Django==4.2.20
                    pip install djangorestframework psycopg2-binary gunicorn
                    pip install pytest pytest-django pytest-cov flake8 black
                    echo "Installed packages:"
                    pip list | grep Django
                '''
                echo '✅ Python environment ready'
            }
        }

        stage('Configure Django Settings') {
            steps {
                sh '''
                    cd backend/hr_core
                    cat > settings.py << 'EOF'
import os
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-jenkins-build-key-2024')
DEBUG = os.environ.get('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = ['*']
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'accounts',
    'employees',
]
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]
ROOT_URLCONF = 'hr_core.urls'
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [],
    'APP_DIRS': True,
    'OPTIONS': {
        'context_processors': [
            'django.template.context_processors.debug',
            'django.template.context_processors.request',
            'django.contrib.auth.context_processors.auth',
            'django.contrib.messages.context_processors.messages',
        ],
    },
}]
WSGI_APPLICATION = 'hr_core.wsgi.application'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'hr_app_db'),
        'USER': os.environ.get('DB_USER', 'postgres'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'postgres'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True
STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOF
                    cd ../..
                '''
                echo '✅ Django settings configured'
            }
        }

        stage('Lint Code') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    echo "Running flake8..."
                    flake8 hr_core/ --count --statistics || echo "⚠️ Linting issues found but continuing"
                    cd ..
                '''
                echo '✅ Linting completed'
            }
        }

        stage('Start Database') {
            steps {
                sh '''
                    docker stop postgres-test 2>/dev/null || true
                    docker rm postgres-test 2>/dev/null || true
                    docker run -d --name postgres-test \
                        -e POSTGRES_DB=hr_app_db \
                        -e POSTGRES_USER=postgres \
                        -e POSTGRES_PASSWORD=postgres \
                        -p 5432:5432 \
                        postgres:15
                    sleep 10
                '''
                echo '✅ Database ready'
            }
        }

        stage('Run Migrations') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    cd ..
                '''
                echo '✅ Migrations completed'
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py test --verbosity=2 --noinput
                    cd ..
                '''
                echo '✅ Tests completed successfully'
            }
        }

        stage('Generate Coverage Report') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    coverage run manage.py test
                    coverage report --show-missing
                    coverage html -d coverage_html
                    cd ..
                '''
                echo '✅ Coverage report generated'
            }
        }

        stage('Build Docker Image') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    echo "Building Docker image: ${DOCKER_IMAGE}"
                    
                    # Create Dockerfile if not exists
                    if [ ! -f "Dockerfile" ]; then
                        cat > Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn psycopg2-binary

# Copy application code
COPY backend /app/backend
COPY config /app/config

# Set working directory
WORKDIR /app/backend

# Collect static files
RUN python manage.py collectstatic --noinput

# Expose port
EXPOSE 8000

# Run gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "hr_core.wsgi:application"]
EOF
                    fi
                    
                    # Build Docker image
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                    
                    echo "✅ Docker image built: ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                '''
                echo '✅ Docker image built successfully'
            }
        }

        stage('Push to Docker Hub') {
            when {
                branch 'main'
                expression { return env.DOCKER_HUB_CREDENTIALS != null }
            }
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "Logging in to Docker Hub as ${DOCKER_HUB_USER}"
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin
                        
                        echo "Pushing Docker images..."
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                        
                        echo "✅ Docker images pushed successfully"
                        echo "Image: ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                        echo "Latest: ${DOCKER_IMAGE}:latest"
                    '''
                }
                echo '✅ Docker image pushed to Docker Hub'
            }
        }

        stage('Deploy to Server') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    echo "========================================="
                    echo "Ready to deploy ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                    echo "========================================="
                    
                    # Example deployment commands (uncomment when ready):
                    
                    # Option 1: Run locally with Docker
                    # docker stop crud-app 2>/dev/null || true
                    # docker rm crud-app 2>/dev/null || true
                    # docker run -d --name crud-app \
                    #   -p 8000:8000 \
                    #   -e DB_HOST=your_db_host \
                    #   -e DB_NAME=hr_app_db \
                    #   -e DB_USER=postgres \
                    #   -e DB_PASSWORD=your_password \
                    #   ${DOCKER_IMAGE}:${BUILD_NUMBER}
                    
                    # Option 2: Deploy to remote server via SSH
                    # ssh user@your-server.com "docker pull ${DOCKER_IMAGE}:${BUILD_NUMBER} && docker-compose up -d"
                    
                    # Option 3: Deploy using docker-compose
                    # docker-compose -f compose.yaml pull
                    # docker-compose -f compose.yaml up -d
                    
                    echo "✅ Deployment preparation completed"
                    echo "To deploy manually, run: docker pull ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                '''
                echo '✅ Deployment stage completed'
            }
        }

        stage('Send Notification') {
            steps {
                echo "========================================="
                echo "Build: ${env.JOB_NAME} - ${env.BUILD_NUMBER}"
                echo "Status: SUCCESS"
                echo "Docker Image: ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                echo "========================================="
            }
            post {
                success {
                    echo '🎉 Build successful! 🎉'
                    echo "Docker image available at: https://hub.docker.com/r/${DOCKER_IMAGE}"
                }
                failure {
                    echo '❌ Build failed! Check logs above. ❌'
                }
            }
        }
    }

    post {
        success {
            echo '🎉🎉🎉 Pipeline completed successfully! 🎉🎉🎉'
            echo "Docker Hub: https://hub.docker.com/r/${DOCKER_IMAGE}"
        }
        failure {
            echo '❌❌❌ Pipeline failed! Check logs above. ❌❌❌'
        }
        always {
            sh '''
                docker stop postgres-test 2>/dev/null || true
                docker rm postgres-test 2>/dev/null || true
                rm -rf venv || true
            '''
            echo '🧹 Cleanup completed'
        }
    }
}
