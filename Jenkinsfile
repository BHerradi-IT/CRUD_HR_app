pipeline {
    agent any

    environment {
        IMAGE_NAME = "crud_hr_app-web"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $IMAGE_NAME .
                '''
            }
        }

        stage('Start Containers') {
            steps {
                sh '''
                docker compose up -d
                '''
            }
        }

        stage('Wait for PostgreSQL') {
            steps {
                sh '''
                echo "Waiting for PostgreSQL..."

                until docker compose exec postgres pg_isready -U hr_app_user -d ytech_hr; do
                  echo "Postgres not ready yet..."
                  sleep 2
                done

                echo "Postgres is READY ✔"
                '''
            }
        }

        stage('Run Migrations') {
            steps {
                sh '''
                docker compose exec web python backend/manage.py migrate
                '''
            }
        }

        stage('Seed Data (Optional)') {
            steps {
                sh '''
                docker compose exec web python backend/manage.py seed_demo || true
                '''
            }
        }

        stage('Run App') {
            steps {
                sh '''
                docker compose exec -d web python backend/manage.py runserver 0.0.0.0:8000
                '''
            }
        }
    }

    post {
        always {
            sh '''
            docker ps
            '''
        }
    }
}
