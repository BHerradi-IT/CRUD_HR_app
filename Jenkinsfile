pipeline {
    agent any

    environment {
        IMAGE_NAME = "hr_app"
        DOCKER_HUB_REPO = "peacechouaib/crud_hr_app"
        CONTAINER_WEB = "hr_app"
        CONTAINER_DB = "hr_postgres"
        TAG = "${BUILD_NUMBER}"
        REPORT_FILE = "trivy-report.txt"
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

        stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                    echo "========== SonarQube Analysis Started =========="

                    docker run --rm \
                      -v $(pwd):/usr/src \
                      -w /usr/src \
                      sonarsource/sonar-scanner-cli:latest \
                      sonar-scanner \
                      -Dsonar.projectKey=hr_app \
                      -Dsonar.projectName="hr_app" \
                      -Dsonar.projectVersion=1.0 \
                      -Dsonar.sources=backend \
                      -Dsonar.exclusions=**/migrations/**,**/__pycache__/**,**/static/** \
                      -Dsonar.host.url=http://192.168.142.142:9000 \
                      -Dsonar.login=$SONAR_TOKEN

                    echo "Sonar analysis completed"
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $IMAGE_NAME:$TAG .
                docker tag $IMAGE_NAME:$TAG $IMAGE_NAME:latest
                '''
            }
        }

        stage('Security Scan (Trivy)') {
            steps {
                sh '''
                trivy image $IMAGE_NAME:$TAG > $REPORT_FILE || echo "Trivy failed" > $REPORT_FILE
                '''
            }
        }

        stage('Docker Hub Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub-cred',
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
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:$TAG
                docker tag $IMAGE_NAME:$TAG $DOCKER_HUB_REPO:latest

                docker push $DOCKER_HUB_REPO:$TAG
                docker push $DOCKER_HUB_REPO:latest
                '''
            }
        }

        stage('Deploy Containers') {
            steps {
                sh '''
                docker compose up -d --build
                '''
            }
        }

        stage('Wait for PostgreSQL') {
            steps {
                sh '''
                until docker exec $CONTAINER_DB pg_isready -U hr_app_user -d ytech_hr; do
                    sleep 2
                done
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

        stage('Seed Data') {
            steps {
                sh '''
                docker exec $CONTAINER_WEB python backend/manage.py seed_demo || true
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                sleep 5
                curl -f http://127.0.0.1:8000 || curl -f http://localhost:8000
                '''
            }
        }
    }

    post {
        success {
            emailext (
                subject: "✅ SUCCESS - Build #${BUILD_NUMBER}",
                body: "Pipeline executed successfully",
                to: "herraditech@gmail.com"
            )
        }

        failure {
            emailext (
                subject: "❌ FAILED - Build #${BUILD_NUMBER}",
                body: "Pipeline failed. Check Jenkins logs.",
                to: "herraditech@gmail.com"
            )
            sh "docker logs hr_app || true"
        }

        always {
            sh "docker ps"
        }
    }
}
