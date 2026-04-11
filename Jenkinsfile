pipeline {
    agent any

    environment {
        APP_NAME = "crud_hr_app"
        IMAGE_NAME = "hr_app"
        DOCKER_HUB_REPO = "peacechouaib/crud_hr_app"
        CONTAINER_WEB = "hr_app"
        CONTAINER_DB = "hr_postgres"
        TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout Source Code') {
            steps {
                checkout scm
            }
        }

        stage('Code Quality Check') {
            steps {
                sh '''
                echo "Running Python Lint..."
                pip install flake8 || true
                flake8 backend || true
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                echo "Building Docker image..."
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
                    echo "Running Trivy scan..."
                    trivy image $IMAGE_NAME:$TAG
                else
                    echo "Trivy not installed, skipping security scan"
                fi
                '''
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                    echo $PASS | docker login -u $USER --password-stdin
                    '''
                }
            }
        }

        stage('Push Image to Docker Hub') {
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
                echo "Starting containers..."
                docker compose up -d --build
                '''
            }
        }

        stage('Wait for PostgreSQL') {
            steps {
                sh '''
                echo "Waiting for PostgreSQL..."

                until docker exec $CONTAINER_DB pg_isready -U hr_app_user -d ytech_hr; do
                    echo "Postgres not ready yet..."
                    sleep 2
                done

                echo "PostgreSQL is READY ✔"
                '''
            }
        }

        stage('Run Database Migrations') {
            steps {
                sh '''
                echo "Running migrations..."
                docker exec $CONTAINER_WEB python backend/manage.py migrate
                '''
            }
        }

        stage('Collect Static Files') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py collectstatic --noinput || true
                '''
            }
        }

        stage('Seed Initial Data') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py seed_demo || true
                '''
            }
        }

    }

    post {
        success {
            echo "✅ Pipeline executed successfully"
        }

        failure {
            echo "❌ Pipeline failed"
            sh "docker logs $CONTAINER_WEB || true"
        }

        always {
            sh "docker ps"
        }
    }
}
