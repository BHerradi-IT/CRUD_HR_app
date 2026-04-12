pipeline {
    agent any

    environment {
        IMAGE_NAME = "hr_app"
        DOCKER_HUB_REPO = "peacechouaib/crud_hr_app"
        CONTAINER_WEB = "hr_app"
        CONTAINER_DB = "hr_postgres"
        TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Code Quality (Lint)') {
            steps {
                sh '''
                echo "Running Lint..."
                pip install flake8 || true
                flake8 backend || true
                '''
            }
        }

        stage('SonarQube Analysis (Optional)') {
            steps {
                sh '''
                if command -v sonar-scanner >/dev/null 2>&1; then
                    echo "Running SonarQube..."
                    sonar-scanner \
                      -Dsonar.projectKey=hr_app \
                      -Dsonar.sources=backend \
                      -Dsonar.host.url=http://localhost:9000 \
                      -Dsonar.login=YOUR_SONAR_TOKEN
                else
                    echo "SonarQube not installed, skipping"
                fi
                '''
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                sh '''
                if command -v trivy >/dev/null 2>&1; then
                    echo "Running Trivy scan..."
                    trivy image python:3.11 || true
                else
                    echo "Trivy not installed, skipping"
                fi
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                echo "Building Docker image..."
                docker build -t $IMAGE_NAME:$TAG .
                docker tag $IMAGE_NAME:$TAG $IMAGE_NAME:latest
                '''
            }
        }

        stage('Tag Image for Docker Hub') {
            steps {
                sh '''
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:$TAG
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:latest
                '''
            }
        }

        stage('Docker Hub Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'USER',
                    passwordVariable: 'PASS'
                )]) {
                    sh '''
                    echo $PASS | docker login -u $USER --password-stdin
                    '''
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh '''
                echo "Pushing image to Docker Hub..."
                docker push $DOCKER_HUB_REPO:$TAG
                docker push $DOCKER_HUB_REPO:latest
                '''
            }
        }

        stage('Deploy Containers') {
            steps {
                sh '''
                echo "Deploying containers..."
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

                echo "PostgreSQL READY ✔"
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

        stage('Collect Static') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py collectstatic --noinput || true
                '''
            }
        }

        stage('Seed Data (Optional)') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py seed_demo || true
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                echo "Checking application..."
                sleep 5
                curl -f http://localhost:8000 || exit 1
                '''
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline SUCCESS"
        }

        failure {
            echo "❌ Pipeline FAILED"
            sh "docker logs $CONTAINER_WEB || true"
        }

        always {
            sh "docker ps"
        }
    }
}
