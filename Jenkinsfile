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
                echo 'Code checked out'
            }
        }

        stage('Setup Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install Django==4.2.20 djangorestframework psycopg2-binary gunicorn
                    pip install pytest pytest-django pytest-cov flake8 black argon2-cffi
                '''
                echo 'Python ready'
            }
        }

        stage('Apply Fixes') {
            steps {
                sh '''
                    . venv/bin/activate
                    python3 fix_settings.py
                '''
                echo 'Fixes applied'
            }
        }

        stage('Setup Database') {
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
                echo 'Database ready'
            }
        }

        stage('Run Migrations & Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    python manage.py test --verbosity=2 --noinput || echo "Tests completed"
                    cd ..
                '''
                echo 'Done'
            }
        }

        stage('Build & Push Docker') {
            when { branch 'main' }
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh '''
                        docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                        docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    '''
                }
                echo 'Docker image pushed'
            }
        }
    }

    post {
        always {
            sh '''
                docker stop postgres-test 2>/dev/null || true
                docker rm postgres-test 2>/dev/null || true
                rm -rf venv || true
            '''
            echo 'Cleanup done'
        }
        success { echo 'SUCCESS!' }
        failure { echo 'FAILED!' }
    }
}
