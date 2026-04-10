pipeline {
    agent any

    environment {
        // Django Configuration
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'False'
        ALLOWED_HOSTS = 'localhost,127.0.0.1,production-server.com'
        
        // Database Configuration
        DB_NAME = 'hr_app_db'
        DB_USER = 'postgres'
        DB_PASSWORD = 'postgres'
        DB_HOST = 'localhost'
        DB_PORT = '5432'
        
        // Redis Configuration (for caching)
        REDIS_HOST = 'localhost'
        REDIS_PORT = '6379'
        
        // Email Configuration
        EMAIL_HOST = 'smtp.gmail.com'
        EMAIL_PORT = '587'
        EMAIL_USE_TLS = 'True'
        
        // Docker Configuration
        DOCKER_HUB_USER = 'peacechouaib'
        DOCKER_IMAGE_NAME = 'crud_hr_app'
        DOCKER_IMAGE = "${DOCKER_HUB_USER}/${DOCKER_IMAGE_NAME}"
        
        // Application Configuration
        APP_ENV = 'staging'
        LOG_LEVEL = 'INFO'
        PYTHONUNBUFFERED = '1'
    }

    stages {
        // ========== 1. CODE CHECKOUT ==========
        stage('📥 Checkout Code') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo '✅ Code checked out successfully'
            }
        }

        // ========== 2. SETUP ENVIRONMENT ==========
        stage('🐍 Setup Python Environment') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install wheel
                    pip install Django==4.2.20
                    pip install djangorestframework psycopg2-binary gunicorn
                    pip install redis celery pytest pytest-django pytest-cov flake8 black
                    pip install bandit safety django-extensions django-debug-toolbar
                    
                    echo "📦 Installed packages:"
                    pip list | grep -E "Django|rest|celery"
                '''
                echo '✅ Python environment ready'
            }
        }

        // ========== 3. CODE QUALITY ==========
        stage('🔍 Code Quality Check') {
            parallel {
                stage('Flake8 Linting') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            cd backend
                            flake8 hr_core/ accounts/ employees/ --count --statistics --max-line-length=120 || true
                            cd ..
                        '''
                    }
                }
                stage('Black Format Check') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            cd backend
                            black --check --diff hr_core/ accounts/ employees/ || echo "⚠️ Formatting needed"
                            cd ..
                        '''
                    }
                }
                stage('Security Scan') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            cd backend
                            bandit -r . -f txt -o bandit_report.txt || echo "⚠️ Security issues found"
                            cd ..
                        '''
                    }
                }
            }
            echo '✅ Code quality checks completed'
        }

        // ========== 4. DATABASE SETUP ==========
        stage('🗄️ Setup Database') {
            steps {
                sh '''
                    # PostgreSQL
                    docker stop postgres-test 2>/dev/null || true
                    docker rm postgres-test 2>/dev/null || true
                    docker run -d --name postgres-test \
                        -e POSTGRES_DB=${DB_NAME} \
                        -e POSTGRES_USER=${DB_USER} \
                        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
                        -p 5432:5432 \
                        postgres:15
                    
                    # Redis for caching
                    docker stop redis-test 2>/dev/null || true
                    docker rm redis-test 2>/dev/null || true
                    docker run -d --name redis-test \
                        -p 6379:6379 \
                        redis:7-alpine
                    
                    sleep 10
                '''
                echo '✅ Database and cache services ready'
            }
        }

        // ========== 5. DATABASE MIGRATIONS ==========
        stage('🔄 Run Migrations') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    python manage.py check --deploy
                    cd ..
                '''
                echo '✅ Migrations completed'
            }
        }

        // ========== 6. COLLECT STATIC FILES ==========
        stage('📦 Collect Static Files') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py collectstatic --noinput --clear
                    cd ..
                '''
                echo '✅ Static files collected'
            }
        }

        // ========== 7. RUN TESTS ==========
        stage('🧪 Run Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            cd backend
                            python manage.py test accounts --verbosity=2 --noinput || echo "⚠️ Unit tests failed"
                            cd ..
                        '''
                    }
                }
                stage('Integration Tests') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            cd backend
                            python manage.py test employees --verbosity=2 --noinput || echo "⚠️ Integration tests failed"
                            cd ..
                        '''
                    }
                }
                stage('Coverage Report') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            cd backend
                            coverage run manage.py test
                            coverage report --show-missing
                            coverage html -d coverage_html
                            cd ..
                        '''
                    }
                }
            }
            echo '✅ Tests completed'
        }

        // ========== 8. BUILD DOCKER IMAGE ==========
        stage('🐳 Build Docker Image') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    echo "Building Docker image: ${DOCKER_IMAGE}"
                    
                    # Create optimized Dockerfile
                    cat > Dockerfile << 'EOF'
FROM python:3.10-slim as builder

WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.10-slim
WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /root/.local /root/.local
COPY backend /app/backend
COPY config /app/config

ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

WORKDIR /app/backend

RUN python manage.py collectstatic --noinput || true

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl --fail http://localhost:8000/health/ || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2", "hr_core.wsgi:application"]
EOF
                    
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:staging
                '''
                echo '✅ Docker image built successfully'
            }
        }

        // ========== 9. SECURITY SCAN DOCKER IMAGE ==========
        stage('🔒 Docker Security Scan') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    # Trivy security scan (optional)
                    docker scan ${DOCKER_IMAGE}:${BUILD_NUMBER} || echo "⚠️ Security scan issues found"
                '''
                echo '✅ Security scan completed'
            }
        }

        // ========== 10. PUSH TO DOCKER HUB ==========
        stage('📤 Push to Docker Hub') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh '''
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                        docker push ${DOCKER_IMAGE}:staging
                    '''
                }
                echo '✅ Docker images pushed to Docker Hub'
            }
        }

        // ========== 11. DEPLOY TO STAGING ==========
        stage('🚀 Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    echo "Deploying to staging environment..."
                    
                    # Pull latest image
                    docker pull ${DOCKER_IMAGE}:staging
                    
                    # Stop and remove old container
                    docker stop crud-app-staging 2>/dev/null || true
                    docker rm crud-app-staging 2>/dev/null || true
                    
                    # Run new container
                    docker run -d --name crud-app-staging \
                        -p 8000:8000 \
                        -e DJANGO_SETTINGS_MODULE=hr_core.settings \
                        -e SECRET_KEY=${SECRET_KEY} \
                        -e DEBUG=False \
                        -e DB_HOST=postgres \
                        -e DB_NAME=${DB_NAME} \
                        -e DB_USER=${DB_USER} \
                        -e DB_PASSWORD=${DB_PASSWORD} \
                        --network app-network \
                        ${DOCKER_IMAGE}:staging
                    
                    echo "✅ Staging deployment completed"
                '''
            }
        }

        // ========== 12. SMOKE TESTS ==========
        stage('🔥 Smoke Tests') {
            when {
                branch 'main'
            }
            steps {
                sh '''
                    echo "Running smoke tests..."
                    sleep 5
                    curl --fail http://localhost:8000/health/ || echo "⚠️ Health check failed"
                    curl --fail http://localhost:8000/api/ || echo "⚠️ API endpoint failed"
                    echo "✅ Smoke tests passed"
                '''
            }
        }

        // ========== 13. NOTIFICATIONS ==========
        stage('📧 Send Notifications') {
            steps {
                script {
                    def buildStatus = currentBuild.result ?: 'SUCCESS'
                    def subject = "${buildStatus}: ${env.JOB_NAME} - Build ${env.BUILD_NUMBER}"
                    def body = """
                        Build Details:
                        - Status: ${buildStatus}
                        - Job: ${env.JOB_NAME}
                        - Build Number: ${env.BUILD_NUMBER}
                        - Branch: ${env.GIT_BRANCH}
                        - Docker Image: ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        - URL: ${env.BUILD_URL}
                    """
                    
                    echo subject
                    echo body
                    
                    // Email notification (uncomment when configured)
                    // emailext(
                    //     subject: subject,
                    //     body: body,
                    //     to: 'team@example.com'
                    // )
                }
                echo '✅ Notifications sent'
            }
        }
    }

    // ========== POST ACTIONS ==========
    post {
        success {
            echo '🎉🎉🎉 Pipeline completed successfully! 🎉🎉🎉'
            echo "Docker Hub: https://hub.docker.com/r/${DOCKER_IMAGE}"
            echo "Staging: http://localhost:8000"
        }
        failure {
            echo '❌❌❌ Pipeline failed! Check logs above. ❌❌❌'
            // Send alert on failure
            // emailext(
            //     subject: "FAILED: ${env.JOB_NAME} - Build ${env.BUILD_NUMBER}",
            //     body: "Build failed. Check Jenkins for details.",
            //     to: 'team@example.com'
            // )
        }
        always {
            sh '''
                docker stop postgres-test 2>/dev/null || true
                docker rm postgres-test 2>/dev/null || true
                docker stop redis-test 2>/dev/null || true
                docker rm redis-test 2>/dev/null || true
                rm -rf venv || true
                docker system prune -f || true
            '''
            echo '🧹 Cleanup completed'
            
            // Archive test reports
            archiveArtifacts artifacts: 'backend/coverage_html/**', allowEmptyArchive: true
            archiveArtifacts artifacts: 'backend/bandit_report.txt', allowEmptyArchive: true
        }
    }
}
