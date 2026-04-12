pipeline {
    agent any

    environment {
        IMAGE_NAME = "hr_app"
        DOCKER_HUB_REPO = "peacechouaib/crud_hr_app"
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
                echo "Scanning image..."
                trivy image $IMAGE_NAME:$TAG > $REPORT_FILE || true
                '''
            }
        }

        stage('Docker Hub Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub-cred',
                    usernameVariable: 'USER',
                    passwordVariable: 'PASS'
                )]) {
                    sh '''
                    echo "Login Docker Hub..."
                    echo $PASS | docker login -u $USER --password-stdin

                    docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:$TAG
                    docker push $DOCKER_HUB_REPO:$TAG
                    '''
                }
            }
        }

        stage('Deploy Containers') {
            steps {
                sh '''
                echo "Deploying..."
                docker compose down || true
                docker compose up -d --build
                '''
            }
        }

        stage('Wait for PostgreSQL') {
            steps {
                sh '''
                echo "Waiting for PostgreSQL..."

                for i in {1..30}; do
                    docker exec hr_postgres pg_isready -U hr_app_user && break
                    echo "DB not ready yet..."
                    sleep 2
                done
                '''
            }
        }

        stage('Run Migrations') {
            steps {
                sh '''
                docker exec hr_app python backend/manage.py migrate
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                echo "Checking app..."
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
                body: "Pipeline executed successfully"
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
