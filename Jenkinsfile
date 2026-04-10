pipeline {
    agent any
    
    environment {
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        ALLOWED_HOSTS = 'localhost,127.0.0.1'
        
        DB_NAME = 'hr_app_db'
        DB_USER = 'postgres'
        DB_PASSWORD = 'postgres'
        DB_HOST = 'localhost'
        DB_PORT = '5432'
        
        PYTHONUNBUFFERED = '1'
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', 
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo 'Code checked out successfully'
            }
        }
        
        stage('Setup Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    
                    pip install --upgrade pip
                    pip install wheel
                    
                    # Install requirements if exists
                    if [ -f "backend/requirements.txt" ]; then
                        pip install -r backend/requirements.txt
                    fi
                    
                    if [ -f "backend/hr_core/requirements.txt" ]; then
                        pip install -r backend/hr_core/requirements.txt
                    fi
                    
                    # Install Django and core packages
                    pip install Django==4.2.20
                    pip install djangorestframework psycopg2-binary gunicorn
                    pip install pytest pytest-django pytest-cov flake8 black
                    
                    echo "Installed packages:"
                    pip list | grep -E "Django|rest"
                '''
                echo 'Python environment ready'
            }
        }
        
        stage('Lint Code') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    flake8 hr_core/ --count --select=E9,F63,F7,F82 --show-source --statistics || true
                    cd ..
                '''
                echo 'Linting completed'
            }
        }
        
        stage('Start Database') {
            steps {
                sh '''
                    docker stop postgres-test 2>/dev/null || true
                    docker rm postgres-test 2>/dev/null || true
                    docker run -d --name postgres-test \
                        -e POSTGRES_DB=hr_app_db \
                        -e POSTGRES_USER=postgres \
                        -e POSTGRES_PASSWORD=postgres \
                        -p 5432:5432 \
                        postgres:15
                    echo "Waiting for database..."
                    sleep 10
                '''
                echo 'Database ready'
            }
        }
        
        stage('Run Migrations') {
            steps {
                sh '''
                    . venv/bin/activate
                    
                    # Go to backend directory where manage.py is
                    cd backend
                    
                    # Run migrations
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    
                    cd ..
                '''
                echo 'Migrations completed'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    
                    cd backend
                    python manage.py test --verbosity=2 --noinput
                    cd ..
                '''
                echo 'Tests completed'
            }
        }
        
        stage('Docker Build (Optional)') {
            when {
                branch 'main'
                expression { return fileExists('compose.yaml') }
            }
            steps {
                sh '''
                    docker-compose -f compose.yaml build
                    echo "Docker image built successfully"
                '''
                echo 'Docker build completed'
            }
        }
    }
    
    post {
        success {
            echo '🎉 Pipeline completed successfully! 🎉'
        }
        failure {
            echo '❌ Pipeline failed! Check logs above. ❌'
        }
        always {
            sh '''
                docker stop postgres-test 2>/dev/null || true
                docker rm postgres-test 2>/dev/null || true
                rm -rf venv || true
            '''
            echo 'Cleanup completed'
        }
    }
}
