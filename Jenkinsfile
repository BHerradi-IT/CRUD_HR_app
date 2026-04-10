pipeline {
    agent any
    
    environment {
        DJANGO_SETTINGS_MODULE = 'config.settings'
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
                    
                    # Install from backend/accounts/requirements.txt
                    if [ -f "backend/accounts/requirements.txt" ]; then
                        pip install -r backend/accounts/requirements.txt
                    fi
                    
                    # Install additional packages
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
                    flake8 backend/accounts/ --count --select=E9,F63,F7,F82 --show-source --statistics || true
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
                    sleep 10
                '''
                echo 'Database ready'
            }
        }
        
        stage('Run Migrations') {
            steps {
                sh '''
                    . venv/bin/activate
                    
                    # Run migrations from the correct location
                    # manage.py is in backend/accounts/
                    cd backend/accounts
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    cd ../..
                '''
                echo 'Migrations completed'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    
                    cd backend/accounts
                    python manage.py test --verbosity=2 --noinput
                    cd ../..
                '''
                echo 'Tests completed'
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed! Check logs above.'
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
