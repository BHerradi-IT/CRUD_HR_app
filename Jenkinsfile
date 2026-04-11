pipeline {
    agent any

    environment {
        IMAGE_NAME = "crud_hr_app-web"
        CONTAINER_WEB = "hr_app"
        CONTAINER_DB = "hr_postgres"
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

                until docker exec $CONTAINER_DB pg_isready -U hr_app_user -d ytech_hr; do
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
                docker exec $CONTAINER_WEB python backend/manage.py migrate
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

        stage('Run App') {
            steps {
                sh '''
                docker exec -d $CONTAINER_WEB python backend/manage.py runserver 0.0.0.0:8000
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
