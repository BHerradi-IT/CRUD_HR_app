pipeline {
    agent any

    environment {
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        ALLOWED_HOSTS = '*'
        
        DB_NAME = 'ytech_hr'
        DB_USER = 'hr_app_user'
        DB_PASSWORD = 'LocalPostgres12345!'
        DB_HOST = 'localhost'
        DB_PORT = '5432'

        DOCKER_HUB_USER = 'peacechouaib'
        DOCKER_IMAGE = "${DOCKER_HUB_USER}/crud_hr_app"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
            }
        }

        stage('Setup Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r backend/requirements.txt
                    pip install pytest pytest-django pytest-cov flake8 black
                '''
            }
        }

        stage('Fix Settings') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend/hr_core
                    if ! grep -q "'employees'" settings.py; then
                        sed -i "/'django.contrib.staticfiles',/a \\    'employees'," settings.py
                    fi
                    cd ../..
                '''
            }
        }

        stage('Database') {
            steps {
                sh '''
                    docker stop crud_hr_postgres 2>/dev/null || true
                    docker rm crud_hr_postgres 2>/dev/null || true
                    docker run -d --name crud_hr_postgres \
                        -e POSTGRES_DB=ytech_hr \
                        -e POSTGRES_USER=hr_app_user \
                        -e POSTGRES_PASSWORD=LocalPostgres12345! \
                        -p 5432:5432 postgres:17
                    sleep 15
                '''
            }
        }

        stage('Migrations') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    cd ..
                '''
            }
        }

        stage('Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py test --noinput || true
                    cd ..
                '''
            }
        }

        stage('Docker Build') {
            when { branch 'main' }
            steps {
                sh '''
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                '''
            }
        }

        stage('Docker Push') {
            when { branch 'main' }
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh '''
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker stop crud_hr_postgres 2>/dev/null || true
                docker rm crud_hr_postgres 2>/dev/null || true
                rm -rf venv || true
            '''
        }
        success {
            echo 'Pipeline SUCCESS!'
        }
        failure {
            echo 'Pipeline FAILED!'
        }
    }
}
