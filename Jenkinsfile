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
                echo "Running lint check..."
                pip install flake8 || true
                flake8 backend || true
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                echo "Building image..."
                docker build -t $IMAGE_NAME:$TAG .
            '''
            }
        }

        stage('Security Scan (Optional Trivy)') {
            steps {
                sh '''
                if command -v trivy >/dev/null 2>&1; then
                    echo "Running Trivy scan..."
                    trivy image $IMAGE_NAME:$TAG
                else
                    echo "Trivy not installed, skipping"
                fi
                '''
            }
        }

       stage('Docker Login') {
    steps {
        withCredentials([usernamePassword(credentialsId: 'docker-hub-cred', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
            sh '''
            echo $PASS | docker login -u $USER --password-stdin
            '''
        }
    }
}

        stage('Push Image') {
            steps {
                sh '''
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:$TAG
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:latest

                docker push $DOCKER_HUB_REPO:$TAG
                docker push $DOCKER_HUB_REPO:latest
                '''
            }
        }

        stage('Wait for PostgreSQL') {
            steps {
                sh '''
                echo "Waiting for PostgreSQL..."

                until docker exec $CONTAINER_DB pg_isready -U hr_app_user -d ytech_hr; do
                    echo "DB not ready..."
                    sleep 2
                done

                echo "PostgreSQL READY ✔"
                '''
            }
        }

        stage('Migrate Database') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py migrate
                '''
            }
        }

        stage('Collect Static (safe)') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py collectstatic --noinput || true
                '''
            }
        }

        stage('Seed Data (safe)') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py seed_demo || true
                '''
            }
        }

    }

    post {
        success {
            echo "✔ Pipeline SUCCESS"
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
