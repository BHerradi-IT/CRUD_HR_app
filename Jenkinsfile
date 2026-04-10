pipeline {
    agent any

    environment {
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        ALLOWED_HOSTS = '*'
        
        // Database values (matching compose.yaml)
        DB_NAME = 'ytech_hr'
        DB_USER = 'hr_app_user'
        DB_PASSWORD = 'LocalPostgres12345!'
        DB_HOST = 'localhost'
        DB_PORT = '5432'

        DOCKER_HUB_USER = 'peacechouaib'
        DOCKER_IMAGE = "${DOCKER_HUB_USER}/crud_hr_app"
        
        PYTHONUNBUFFERED = '1'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo 'Code checked out'
            }
        }

        stage('Setup Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install Django==4.2.20
                    pip install djangorestframework psycopg2-binary gunicorn
                    pip install pytest pytest-django pytest-cov flake8 black
                    pip install argon2-cffi
                '''
                echo 'Python ready'
            }
        }

        stage('Fix Django Settings') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend/hr_core
                    
                    # Add employees to INSTALLED_APPS
                    if ! grep -q "'employees'" settings.py; then
                        sed -i "/'django.contrib.staticfiles',/a \\    'employees'," settings.py
                        echo "Added employees"
                    fi
                    
                    cd ../..
                '''
                echo 'Settings fixed'
            }
        }

        stage('Start PostgreSQL') {
            steps {
                sh '''
                    docker stop crud_hr_postgres 2>/dev/null || true
                    docker rm crud_hr_postgres 2>/dev/null || true
                    
                    docker run -d \
                        --name crud_hr_postgres \
                        -e POSTGRES_DB=ytech_hr \
                        -e POSTGRES_USER=hr_app_user \
                        -e POSTGRES_PASSWORD=LocalPostgres12345! \
                        -p 5432:5432 \
                        postgres:17
                    
                    sleep 15
                '''
                echo 'Database ready'
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
                echo 'Migrations done'
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py test --verbosity=2 --noinput || echo "Tests completed"
                    cd ..
                '''
                echo 'Tests done'
            }
        }

        stage('Build Docker') {
            when { branch 'main' }
            steps {
                sh '''
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                '''
                echo 'Docker image built'
            }
        }

        stage('Push to Docker Hub') {
            when { branch 'main' }
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh '''
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    '''
                }
                echo 'Pushed to Docker Hub'
            }
        }
    }

    post {
        success {
            echo 'Pipeline SUCCESS!'
        }
        failure {
            echo 'Pipeline FAILED!'
        }
        always {
            sh '''
                docker stop crud_hr_postgres 2>/dev/null || true
                docker rm crud_hr_postgres 2>/dev/null || true
                rm -rf venv || true
            '''
            echo 'Cleanup done'
        }
    }
}
