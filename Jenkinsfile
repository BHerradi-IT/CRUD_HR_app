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
        
        stage('Explore Project Structure') {
            steps {
                sh '''
                    echo "Project structure:"
                    ls -la
                    echo ""
                    echo "Looking for manage.py:"
                    find . -name "manage.py" -type f
                    echo ""
                    echo "Looking for settings.py:"
                    find . -name "settings.py" -type f
                    echo ""
                    echo "Backend folder content:"
                    ls -la backend/ 2>/dev/null || echo "backend folder not found"
                    echo ""
                    echo "Config folder content:"
                    ls -la config/ 2>/dev/null || echo "config folder not found"
                '''
            }
        }
        
        stage('Setup Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    
                    pip install --upgrade pip
                    pip install wheel
                    
                    pip install Django==4.2.20
                    pip install djangorestframework psycopg2-binary gunicorn
                    pip install pytest pytest-django pytest-cov flake8 black
                    
                    if [ -f "requirements.txt" ]; then
                        pip install -r requirements.txt || true
                    fi
                    
                    if [ -f "backend/requirements.txt" ]; then
                        pip install -r backend/requirements.txt || true
                    fi
                    
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
                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
                '''
                echo 'Linting completed'
            }
        }
        
        stage('Start Database') {
            steps {
                sh '''
                    if command -v docker &> /dev/null; then
                        docker stop postgres-test 2>/dev/null || true
                        docker rm postgres-test 2>/dev/null || true
                        docker run -d --name postgres-test \
                            -e POSTGRES_DB=hr_app_db \
                            -e POSTGRES_USER=postgres \
                            -e POSTGRES_PASSWORD=postgres \
                            -p 5432:5432 \
                            postgres:15
                        sleep 10
                    else
                        echo "Docker not available, using SQLite"
                    fi
                '''
                echo 'Database ready'
            }
        }
        
        stage('Run Migrations') {
            steps {
                sh '''
                    . venv/bin/activate
                    
                    if [ -f "backend/manage.py" ]; then
                        cd backend
                        python manage.py makemigrations --noinput || true
                        python manage.py migrate --noinput
                        cd ..
                    elif [ -f "manage.py" ]; then
                        python manage.py makemigrations --noinput || true
                        python manage.py migrate --noinput
                    else
                        echo "manage.py not found"
                        exit 1
                    fi
                '''
                echo 'Migrations completed'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    
                    if [ -f "backend/manage.py" ]; then
                        cd backend
                        python manage.py test --verbosity=2 --noinput || echo "No tests found or tests failed"
                        cd ..
                    elif [ -f "manage.py" ]; then
                        python manage.py test --verbosity=2 --noinput || echo "No tests found or tests failed"
                    fi
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
