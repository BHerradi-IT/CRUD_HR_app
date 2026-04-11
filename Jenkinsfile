pipeline {
    agent any

    stages {

        stage('Clone') {
            steps {
                git branch: 'main', url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
            }
        }

        stage('Build & Run') {
            steps {
                script {
                    sh "docker compose down || true"
                    sh "docker compose up -d --build"
                }
            }
        }

        stage('Test App') {
            steps {
                script {
                    sh "sleep 10"
                    sh "curl -f http://localhost:8000 || exit 1"
                }
            }
        }
    }
}
