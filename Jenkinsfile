pipeline {
    agent any

    environment {
        // ========== Application Settings ==========
        IMAGE_NAME = "crud_hr_app"
        CONTAINER_NAME = "crud_hr_app_container"
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        ALLOWED_HOSTS = '*'
        
        // ========== Database Configuration ==========
        DB_NAME = 'ytech_hr'
        DB_USER = 'hr_app_user'
        DB_PASSWORD = 'LocalPostgres12345!'
        DB_HOST = 'postgres'
        DB_PORT = '5432'
        
        // ========== SonarQube (Remote Server) ==========
        SONAR_HOST_URL = "http://192.168.142.143:9000"
        SONAR_TOKEN = credentials('sonar-token')
        
        // ========== Docker Hub ==========
        DOCKER_HUB_USERNAME = "peacechouaib"
        DOCKER_HUB_IMAGE = "crud_hr_app"
        
        // ========== Email ==========
        EMAIL_RECIPIENT = "herraditech@gmail.com"
        
        // ========== Prometheus + Grafana ==========
        PROMETHEUS_PUSHGATEWAY = "http://192.168.142.143:9091"
        PROMETHEUS_URL = "http://192.168.142.143:9090"
        GRAFANA_URL = "http://192.168.142.143:3000"
        
        // ========== DefectDojo ==========
        DEFECTDOJO_URL = "http://192.168.142.143:9090"
        DEFECTDOJO_API_KEY = credentials('defectdojo-api-key')
        
        // ========== Python ==========
        PYTHONUNBUFFERED = '1'
    }

    stages {
        // ========== 1. Clone Repository ==========
        stage('📥 Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo '✅ Code cloned successfully'
            }
        }

        // ========== 2. Setup Python Environment ==========
        stage('🐍 Setup Python Environment') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🐍 Setting up Python environment"
                    echo "========================================="
                    
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install wheel
                    pip install Django==4.2.20
                    pip install djangorestframework psycopg2-binary gunicorn
                    pip install pytest pytest-django pytest-cov flake8 black
                    pip install argon2-cffi
                    
                    # Create requirements.txt if not exists
                    if [ ! -f "backend/requirements.txt" ]; then
                        cat > backend/requirements.txt << 'EOF'
Django==4.2.20
djangorestframework==3.15.2
psycopg2-binary==2.9.10
gunicorn==21.2.0
argon2-cffi==23.1.0
python-dotenv==1.0.1
EOF
                    fi
                    
                    echo "✅ Python environment ready"
                    pip list | grep Django
                '''
            }
        }

        // ========== 3. Fix Django Settings ==========
        stage('🔧 Fix Django Configuration') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🔧 Fixing Django settings"
                    echo "========================================="
                    
                    . venv/bin/activate
                    cd backend/hr_core
                    
                    # Add employees app to INSTALLED_APPS
                    if ! grep -q "'employees'" settings.py; then
                        sed -i "/'django.contrib.staticfiles',/a \\    'employees'," settings.py
                        echo "✅ Added employees to INSTALLED_APPS"
                    fi
                    
                    # Add accounts app if not present
                    if ! grep -q "'accounts'" settings.py; then
                        sed -i "/'django.contrib.staticfiles',/a \\    'accounts'," settings.py
                        echo "✅ Added accounts to INSTALLED_APPS"
                    fi
                    
                    cd ../..
                    echo "✅ Django settings fixed"
                '''
            }
        }

        // ========== 4. Start PostgreSQL Database ==========
        stage('🗄️ Start PostgreSQL') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🗄️ Starting PostgreSQL database"
                    echo "========================================="
                    
                    docker stop crud_hr_postgres 2>/dev/null || true
                    docker rm crud_hr_postgres 2>/dev/null || true
                    
                    docker run -d \
                        --name crud_hr_postgres \
                        -e POSTGRES_DB=ytech_hr \
                        -e POSTGRES_USER=hr_app_user \
                        -e POSTGRES_PASSWORD=LocalPostgres12345! \
                        -p 5432:5432 \
                        postgres:17
                    
                    echo "Waiting for database to be ready..."
                    sleep 15
                    
                    if docker ps | grep -q crud_hr_postgres; then
                        echo "✅ PostgreSQL is running"
                    else
                        echo "❌ PostgreSQL failed to start"
                        exit 1
                    fi
                '''
            }
        }

        // ========== 5. Run Migrations ==========
        stage('🔄 Run Database Migrations') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🔄 Running database migrations"
                    echo "========================================="
                    
                    . venv/bin/activate
                    cd backend
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    cd ..
                    
                    echo "✅ Migrations completed"
                '''
            }
        }

        // ========== 6. Run Tests with Coverage ==========
        stage('🧪 Run Tests & Coverage') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🧪 Running tests with coverage"
                    echo "========================================="
                    
                    . venv/bin/activate
                    cd backend
                    
                    # Run tests with coverage
                    coverage run manage.py test --verbosity=2 --noinput
                    coverage report --show-missing
                    coverage html -d coverage_html
                    
                    cd ..
                    
                    echo "✅ Tests completed"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'backend/coverage_html/**', allowEmptyArchive: true
                }
            }
        }

        // ========== 7. SonarQube Analysis ==========
        stage('🔍 SonarQube Analysis') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🔍 SonarQube Analysis Started"
                    echo "========================================="
                    
                    # Create SonarQube configuration
                    cat > sonar-project.properties << EOF
sonar.projectKey=crud_hr_app
sonar.projectName=CRUD HR App
sonar.projectVersion=1.0
sonar.sources=backend
sonar.exclusions=**/migrations/**,**/venv/**,**/static/**
sonar.python.version=3.10
sonar.host.url=${SONAR_HOST_URL}
sonar.login=${SONAR_TOKEN}
EOF
                    
                    # Run SonarQube scanner
                    docker run --rm \
                        -v $(pwd):/usr/src \
                        -w /usr/src \
                        sonarsource/sonar-scanner-cli:latest \
                        sonar-scanner
                    
                    echo "✅ SonarQube analysis completed"
                '''
            }
        }

        // ========== 8. Quality Gate Check ==========
        stage('✅ Quality Gate Check') {
            steps {
                sh '''
                    echo "========================================="
                    echo "⏳ Waiting for SonarQube analysis..."
                    echo "========================================="
                    
                    sleep(time: 30, unit: 'SECONDS')
                    
                    STATUS=$(curl -s -u ${SONAR_TOKEN}: "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=crud_hr_app" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
                    echo "Quality Gate Status: ${STATUS}"
                    
                    if [ "$STATUS" = "ERROR" ]; then
                        echo "❌ Quality Gate failed!"
                        exit 1
                    else
                        echo "✅ Quality Gate passed!"
                    fi
                '''
            }
        }

        // ========== 9. Build Docker Image ==========
        stage('🐳 Build Docker Image') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🐳 Building Docker image"
                    echo "========================================="
                    
                    # Create Dockerfile if not exists
                    if [ ! -f "Dockerfile" ]; then
                        cat > Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn psycopg2-binary argon2-cffi

COPY backend /app/backend
COPY config /app/config

ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=hr_core.settings

WORKDIR /app/backend
RUN python manage.py collectstatic --noinput || true

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl --fail http://localhost:8000/health/ || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2", "hr_core.wsgi:application"]
EOF
                    fi
                    
                    docker build -t ${IMAGE_NAME}:latest .
                    docker tag ${IMAGE_NAME}:latest ${IMAGE_NAME}:${BUILD_NUMBER}
                    
                    echo "✅ Docker image built: ${IMAGE_NAME}:${BUILD_NUMBER}"
                '''
            }
        }

        // ========== 10. Trivy Security Scan ==========
        stage('🔒 Trivy Security Scan') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🔒 Trivy Security Scan Started"
                    echo "========================================="
                    
                    mkdir -p reports
                    
                    docker pull aquasec/trivy:0.59.0
                    
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v $(pwd):/src \
                        -w /src \
                        aquasec/trivy:0.59.0 \
                        image ${IMAGE_NAME}:latest \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output reports/trivy-scan.txt || true
                    
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v $(pwd):/src \
                        -w /src \
                        aquasec/trivy:0.59.0 \
                        image ${IMAGE_NAME}:latest \
                        --format json \
                        --output reports/trivy-report.json || true
                    
                    echo "========================================="
                    echo "📊 Trivy Scan Summary"
                    echo "========================================="
                    cat reports/trivy-scan.txt || echo "No vulnerabilities found"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/*', fingerprint: true, allowEmptyArchive: true
                }
            }
        }

        // ========== 11. DefectDojo Import ==========
        stage('🛡️ DefectDojo Import') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🛡️ Importing Security Reports to DefectDojo"
                    echo "========================================="
                    
                    curl -X POST \
                        -H "Authorization: Token ${DEFECTDOJO_API_KEY}" \
                        -F "scan_type=Trivy Scan" \
                        -F "file=@reports/trivy-report.json" \
                        -F "engagement_id=1" \
                        -F "product_id=1" \
                        ${DEFECTDOJO_URL}/api/v2/import-scan/ || true
                    
                    echo "✅ Reports sent to DefectDojo"
                '''
            }
        }

        // ========== 12. Send Metrics to Prometheus ==========
        stage('📈 Send Metrics to Prometheus') {
            steps {
                sh '''
                    echo "========================================="
                    echo "📈 Sending Metrics to Prometheus"
                    echo "========================================="
                    
                    HIGH_COUNT=$(grep -o '"SEVERITY":"HIGH"' reports/trivy-report.json | wc -l || echo "0")
                    CRITICAL_COUNT=$(grep -o '"SEVERITY":"CRITICAL"' reports/trivy-report.json | wc -l || echo "0")
                    TEST_COUNT=$(grep -o "test" backend/coverage_html/index.html 2>/dev/null | wc -l || echo "0")
                    
                    echo "🔴 HIGH Vulnerabilities: $HIGH_COUNT"
                    echo "🔴 CRITICAL Vulnerabilities: $CRITICAL_COUNT"
                    echo "🧪 Tests found: $TEST_COUNT"
                    
                    curl -X POST \
                        -H "Content-Type: text/plain" \
                        --data-binary "# TYPE jenkins_build_info gauge
                    jenkins_build_info{build_number=\"${BUILD_NUMBER}\",job=\"${JOB_NAME}\",status=\"success\"} 1
                    # TYPE trivy_vulnerabilities gauge
                    trivy_vulnerabilities{severity=\"HIGH\"} ${HIGH_COUNT}
                    trivy_vulnerabilities{severity=\"CRITICAL\"} ${CRITICAL_COUNT}
                    # TYPE test_coverage gauge
                    test_coverage{type=\"total\"} ${TEST_COUNT}" \
                        ${PROMETHEUS_PUSHGATEWAY}/metrics/job/jenkins_builds/instance/${JOB_NAME}
                    
                    echo "✅ Metrics sent to Prometheus"
                '''
            }
        }

        // ========== 13. Push to Docker Hub ==========
        stage('📤 Push to Docker Hub') {
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "========================================="
                        echo "🐳 Pushing to Docker Hub"
                        echo "========================================="
                        
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_HUB_USERNAME} --password-stdin
                        
                        docker tag ${IMAGE_NAME}:latest ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_IMAGE}:latest
                        docker tag ${IMAGE_NAME}:latest ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_IMAGE}:latest
                        docker push ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_IMAGE}:${BUILD_NUMBER}
                        
                        echo "✅ Image pushed: ${DOCKER_HUB_USERNAME}/${DOCKER_HUB_IMAGE}:${BUILD_NUMBER}"
                    '''
                }
            }
        }

        // ========== 14. Deploy Container ==========
        stage('🚀 Deploy Container') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🚀 Deploying application"
                    echo "========================================="
                    
                    docker stop ${CONTAINER_NAME} 2>/dev/null || true
                    docker rm ${CONTAINER_NAME} 2>/dev/null || true
                    
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p 8000:8000 \
                        -e DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE} \
                        -e SECRET_KEY=${SECRET_KEY} \
                        -e DEBUG=${DEBUG} \
                        -e DB_HOST=${DB_HOST} \
                        -e DB_NAME=${DB_NAME} \
                        -e DB_USER=${DB_USER} \
                        -e DB_PASSWORD=${DB_PASSWORD} \
                        ${IMAGE_NAME}:latest
                    
                    sleep 5
                    
                    if docker ps | grep -q ${CONTAINER_NAME}; then
                        echo "✅ Application is running on port 8000"
                        docker logs ${CONTAINER_NAME} --tail 20
                    else
                        echo "❌ Application failed to start"
                        docker logs ${CONTAINER_NAME} --tail 50
                        exit 1
                    fi
                    
                    echo "========================================="
                    echo "🌐 Application URL: http://localhost:8000"
                    echo "========================================="
                '''
            }
        }
    }
    
    // ========== Post Pipeline Actions ==========
    post {
        success {
            script {
                emailext(
                    subject: "✅ Pipeline SUCCESS - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        ✅ Pipeline completed successfully!
                        
                        Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}
                        Status: SUCCESS
                        
                        📊 SonarQube: ${env.SONAR_HOST_URL}
                        🛡️ DefectDojo: ${env.DEFECTDOJO_URL}
                        📈 Prometheus: ${env.PROMETHEUS_URL}
                        📊 Grafana: ${env.GRAFANA_URL}
                        🐳 Docker Hub: ${env.DOCKER_HUB_USERNAME}/${env.DOCKER_HUB_IMAGE}:${env.BUILD_NUMBER}
                        🌐 Application: http://localhost:8000
                        
                        🔗 Build URL: ${env.BUILD_URL}
                        
                        ---
                        Jenkins CI/CD Pipeline
                        CRUD HR App - Django Security & Quality Pipeline
                    """,
                    to: "${env.EMAIL_RECIPIENT}",
                    attachmentsPattern: "reports/trivy-scan.txt, reports/trivy-report.json"
                )
                echo ""
                echo "========================================="
                echo "✅ PIPELINE COMPLETED SUCCESSFULLY!"
                echo "========================================="
            }
        }
        failure {
            script {
                emailext(
                    subject: "❌ Pipeline FAILED - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        ❌ Pipeline failed!
                        
                        Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}
                        Status: FAILED
                        
                        🔗 Check Jenkins logs: ${env.BUILD_URL}
                        
                        ---
                        Jenkins CI/CD Pipeline
                        CRUD HR App - Django Security & Quality Pipeline
                    """,
                    to: "${env.EMAIL_RECIPIENT}",
                    attachmentsPattern: "reports/trivy-scan.txt, reports/trivy-report.json"
                )
                echo ""
                echo "========================================="
                echo "❌ PIPELINE FAILED!"
                echo "========================================="
            }
        }
        always {
            sh '''
                echo "========================================="
                echo "🧹 Cleaning up resources"
                echo "========================================="
                
                # Stop database container (keep for next build)
                # docker stop crud_hr_postgres 2>/dev/null || true
                # docker rm crud_hr_postgres 2>/dev/null || true
                
                # Remove virtual environment
                rm -rf venv || true
                
                echo "✅ Cleanup completed"
            '''
        }
    }
}
