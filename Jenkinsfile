pipeline {
    agent any

    environment {
        IMAGE_NAME = "hr_app"
        DOCKER_HUB_REPO = "YOUR_DOCKERHUB_USERNAME/crud_hr_app"
        CONTAINER_WEB = "hr_app"
        CONTAINER_DB = "hr_postgres"
        TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Code Quality (Basic Lint)') {
            steps {
                sh '''
                echo "Running basic Python checks..."
                python3 --version || true
                pip install flake8 || true
                flake8 backend || true
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $IMAGE_NAME:$TAG .
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:$TAG
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:latest
                '''
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                sh '''
                if command -v trivy >/dev/null 2>&1; then
                    trivy image $IMAGE_NAME:$TAG
                else
                    echo "Trivy not installed, skipping scan"
                fi
                '''
            }
        }

        stage('Login to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                    echo $PASS | docker login -u $USER --password-stdin
                    '''
                }
            }
        }

        stage('Push Image') {
            steps {
                sh '''
                docker push $DOCKER_HUB_REPO:$TAG
                docker push $DOCKER_HUB_REPO:latest
                '''
            }
        }

        stage('Deploy (Docker Compose)') {
            steps {
                sh '''
                docker compose up -d --build
                '''
            }
        }

        stage('Wait for PostgreSQL') {
            steps {
                sh '''
                echo "Waiting for PostgreSQL..."

                until docker exec $CONTAINER_DB pg_isready -U hr_app_user -d ytech_hr; do
                  echo "Postgres not ready..."
                  sleep 2
                done

                echo "PostgreSQL is ready ✔"
                '''
            }
        }

        stage('Run Migrations') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py migrate
                '''
            }
        }

        stage('Collect Static (optional)') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py collectstatic --noinput || true
                '''
            }
        }

        stage('Run Seed Data (optional)') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py seed_demo || true
                '''
            }
        }

    }

    post {
        success {
            echo "Pipeline SUCCESS ✔"
        }

        failure {
            echo "Pipeline FAILED ❌"
            sh "docker logs $CONTAINER_WEB || true"
        }

        always {
            sh "docker ps"
        }
    }
}
