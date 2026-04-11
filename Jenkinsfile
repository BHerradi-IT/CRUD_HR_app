pipeline {
    agent any

    environment {
        IMAGE_NAME = "hr_app"
        CONTAINER_NAME = "hr_app_container"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t hr_app .'
            }
        }

        stage('Stop Old Containers') {
            steps {
                sh '''
                docker stop hr_app_container || true
                docker rm hr_app_container || true
                '''
            }
        }

        stage('Run PostgreSQL (if not running)') {
            steps {
                sh '''
                docker ps | grep hr_postgres || docker run -d \
                --name hr_postgres \
                -e POSTGRES_DB=ytech_hr \
                -e POSTGRES_USER=hr_app_user \
                -e POSTGRES_PASSWORD=LocalPostgres12345! \
                -p 5432:5432 \
                postgres:15
                '''
            }
        }

        stage('Run Migrations') {
            steps {
                sh '''
                docker run --rm \
                --network host \
                -e DATABASE_URL=postgres://hr_app_user:LocalPostgres12345!@localhost:5432/ytech_hr \
                hr_app python backend/manage.py migrate
                '''
            }
        }

        stage('Run Container') {
            steps {
                sh '''
                docker run -d \
                --name hr_app_container \
                --network host \
                -e DATABASE_URL=postgres://hr_app_user:LocalPostgres12345!@localhost:5432/ytech_hr \
                -p 8000:8000 \
                hr_app python backend/manage.py runserver 0.0.0.0:8000
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline executed successfully 🚀'
        }
        failure {
            echo 'Pipeline failed ❌'
        }
    }
}
