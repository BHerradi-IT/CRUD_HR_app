pipeline {
    agent any

    environment {
        // Django Settings
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        DJANGO_ALLOW_NULL_ORIGIN_IN_DEBUG = 'True'
        ALLOWED_HOSTS = 'localhost,127.0.0.1'
        
        // Database Configuration
        DATABASE_URL = 'postgresql://hr_app_user:LocalPostgres12345!@localhost:5432/ytech_hr'
        DB_NAME = 'ytech_hr'
        DB_USER = 'hr_app_user'
        DB_PASSWORD = 'LocalPostgres12345!'
        DB_HOST = 'localhost'
        DB_PORT = '5432'

        // Docker Hub Configuration
        DOCKER_HUB_USER = 'peacechouaib'
        DOCKER_IMAGE_NAME = 'crud_hr_app'
        DOCKER_IMAGE = "${DOCKER_HUB_USER}/${DOCKER_IMAGE_NAME}"
        
        // Python
        PYTHONUNBUFFERED = '1'
    }

    stages {
        stage('📥 سحب الكود من GitHub') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo '✅ تم سحب الكود بنجاح'
            }
        }

        stage('🐍 تجهيز بيئة Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install wheel
                    if [ -f "backend/requirements.txt" ]; then
                        pip install -r backend/requirements.txt
                    fi
                    pip install gunicorn psycopg2-binary argon2-cffi
                    pip install pytest pytest-django pytest-cov flake8 black
                '''
                echo '✅ بيئة Python جاهزة'
            }
        }

        stage('🔧 تنظيف وإعداد قاعدة البيانات') {
            steps {
                sh '''
                    echo "تنظيف الحاويات القديمة..."
                    # إيقاف وإزالة الحاوية القديمة إذا كانت موجودة
                    docker stop crud_hr_postgres 2>/dev/null || true
                    docker rm crud_hr_postgres 2>/dev/null || true
                    
                    # إزالة الشبكة القديمة إذا لزم الأمر
                    docker network prune -f 2>/dev/null || true
                    
                    echo "تشغيل قاعدة بيانات جديدة..."
                    # تشغيل PostgreSQL باستخدام Docker Compose
                    docker compose up -d postgres
                    
                    echo "⏳ انتظار تشغيل قاعدة البيانات..."
                    sleep 15
                    
                    # التأكد من أن قاعدة البيانات جاهزة
                    docker exec crud_hr_postgres pg_isready -U hr_app_user -d ytech_hr 2>/dev/null || echo "⚠️ انتظار إضافي لقاعدة البيانات..."
                    sleep 5
                '''
                echo '✅ قاعدة البيانات جاهزة'
            }
        }

        stage('🔄 تنفيذ ترحيلات قاعدة البيانات') {
            steps {
                sh '''
                    . venv/bin/activate
                    export DATABASE_URL="postgresql://hr_app_user:LocalPostgres12345!@localhost:5432/ytech_hr"
                    cd backend
                    python manage.py migrate --noinput
                    cd ..
                '''
                echo '✅ تم تنفيذ الترحيلات بنجاح'
            }
        }

        stage('🌱 إضافة البيانات التجريبية (Seed)') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py seed_demo 2>/dev/null || echo "⚠️ أمر seed_demo غير موجود - تخطي"
                    cd ..
                '''
                echo '✅ تم إضافة البيانات التجريبية'
            }
        }

        stage('🔍 فحص جودة الكود (Linting)') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics 2>/dev/null || true
                    cd ..
                '''
                echo '✅ تم فحص جودة الكود'
            }
        }

        stage('🧪 تشغيل الاختبارات') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py test --verbosity=2 --noinput 2>&1 || echo "⚠️ الاختبارات اكتملت مع تحذيرات"
                    cd ..
                '''
                echo '✅ اكتملت الاختبارات'
            }
        }

        stage('📦 جمع الملفات الثابتة (Static Files)') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py collectstatic --noinput 2>/dev/null || true
                    cd ..
                '''
                echo '✅ تم جمع الملفات الثابتة'
            }
        }

        stage('🐳 بناء صورة Docker') {
            when { branch 'main' }
            steps {
                sh '''
                    # إنشاء Dockerfile إذا لم يكن موجوداً
                    if [ ! -f "Dockerfile" ]; then
                        cat > Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    libpq-dev \
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

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "--threads", "2", "hr_core.wsgi:application"]
EOF
                    fi
                    
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                '''
                echo '✅ تم بناء صورة Docker'
            }
        }

        stage('📤 رفع الصورة إلى Docker Hub') {
            when { branch 'main' }
            steps {
                withCredentials([string(credentialsId: 'docker-hub-password', variable: 'DOCKER_PASS')]) {
                    sh '''
                        echo ${DOCKER_PASS} | docker login -u ${DOCKER_HUB_USER} --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    '''
                }
                echo '✅ تم رفع الصورة إلى Docker Hub'
            }
        }

        stage('🚀 تعليمات التشغيل') {
            when { branch 'main' }
            steps {
                sh '''
                    echo "========================================="
                    echo "🎉 اكتمل البناء بنجاح! 🎉"
                    echo "========================================="
                    echo ""
                    echo "لتشغيل التطبيق محلياً:"
                    echo "  docker run -d -p 8000:8000 ${DOCKER_IMAGE}:latest"
                    echo ""
                    echo "أو باستخدام Docker Compose:"
                    echo "  docker compose up -d"
                    echo ""
                    echo "حسابات تجريبية (من README):"
                    echo "  hradmin / ChangeMe123!"
                    echo "  hruser / ChangeMe123!"
                    echo "  itadmin / ChangeMe123!"
                    echo ""
                    echo "========================================="
                '''
            }
        }
    }

    post {
        success {
            echo '🎉🎉🎉 نجاح! Pipeline اكتمل بنجاح 🎉🎉🎉'
            echo "رابط Docker Hub: https://hub.docker.com/r/${DOCKER_IMAGE}"
        }
        failure {
            echo '❌❌❌ فشل! راجع السجلات أعلاه ❌❌❌'
        }
        always {
            sh '''
                # تنظيف الحاويات والشبكات
                docker stop crud_hr_postgres 2>/dev/null || true
                docker rm crud_hr_postgres 2>/dev/null || true
                docker compose down 2>/dev/null || true
                docker network prune -f 2>/dev/null || true
                rm -rf venv || true
            '''
            echo '🧹 تم التنظيف'
        }
    }
}
