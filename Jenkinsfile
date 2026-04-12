pipeline {
    agent any

    environment {
        IMAGE_NAME = "hr_app"
        DOCKER_HUB_REPO = "peacechouaib/crud_hr_app"
        CONTAINER_WEB = "hr_app"
        CONTAINER_DB = "hr_postgres"
        TAG = "${BUILD_NUMBER}"

        SONAR_HOST_URL = "http://192.168.142.143:9000"
        REPORT_FILE = "trivy-report.txt"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Lint Code') {
            steps {
                sh '''
                echo "Running Flake8..."
                pip install flake8 || true
                flake8 backend || true
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                    echo "Running SonarQube..."

                    docker run --rm \
                      -v $(pwd):/usr/src \
                      -w /usr/src \
                      sonarsource/sonar-scanner-cli \
                      sonar-scanner \
                      -Dsonar.projectKey=hr_app \
                      -Dsonar.sources=backend \
                      -Dsonar.host.url=$SONAR_HOST_URL \
                      -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                echo "Building Docker image..."
                docker build -t $IMAGE_NAME:$TAG .
                '''
            }
        }

        stage('Trivy Security Scan') {
            steps {
                sh '''
                echo "Scanning image with Trivy..."
                trivy image $IMAGE_NAME:$TAG > $REPORT_FILE || true
                '''
            }
        }

        stage('Docker Hub Login & Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub-cred',
                    usernameVariable: 'USER',
                    passwordVariable: 'PASS'
                )]) {
                    sh '''
                    echo "Logging into Docker Hub..."
                    echo $PASS | docker login -u $USER --password-stdin

                    docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:$TAG
                    docker push $DOCKER_HUB_REPO:$TAG
                    '''
                }
            }
        }

        stage('Deploy (Docker Compose)') {
            steps {
                sh '''
                echo "Deploying containers..."
                docker compose down || true
                docker compose up -d --build
                '''
            }
        }

        stage('Database Migration') {
            steps {
                sh '''
                echo "Waiting DB and running migrations..."
                sleep 10
                docker exec hr_app python backend/manage.py migrate
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                echo "Checking app..."
                sleep 5
                curl -f http://localhost:8000 || exit 1
                '''
            }
        }
    }

    post {
        success {
            emailext (
                to: "herraditech@gmail.com",
                subject: "✅ SUCCESS Build #${BUILD_NUMBER}",
                body: "Pipeline executed successfully for HR App"
            )
        }

        failure {
            emailext (
                to: "herraditech@gmail.com",
                subject: "❌ FAILED Build #${BUILD_NUMBER}",
                body: "Check Jenkins logs"
            )
        }

        always {
            sh "docker ps"
        }
    }
}
