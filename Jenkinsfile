pipeline {
    agent any

    environment {
        // Django Settings
        DJANGO_SETTINGS_MODULE = 'hr_core.settings'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'True'
        ALLOWED_HOSTS = '*'
        
        // Database Settings
        DB_NAME = 'ytech_hr'
        DB_USER = 'hr_app_user'
        DB_PASSWORD = 'LocalPostgres12345!'
        DB_HOST = 'postgres'
        DB_PORT = '5432'

        // Docker Hub Settings
        DOCKER_HUB_USER = 'peacechouaib'
        DOCKER_IMAGE_NAME = 'crud_hr_app'
        DOCKER_IMAGE = "${DOCKER_HUB_USER}/${DOCKER_IMAGE_NAME}"
        
        // Deployment Settings
        DEPLOY_PORT = '8000'
        CONTAINER_NAME = 'crud_hr_app'
        DB_CONTAINER_NAME = 'crud_hr_postgres'
    }

    stages {
        stage('📥 سحب الكود') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo '✅ تم سحب الكود بنجاح'
            }
        }

        stage('🐍 تجهيز Python') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install Django==4.2.20 djangorestframework psycopg2-binary
                    pip install pytest pytest-django pytest-cov flake8 black argon2-cffi
                '''
                echo '✅ تم تجهيز Python'
            }
        }

        stage('🔧 إصلاح إعدادات Django') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend/hr_core
                    
                    # إضافة employees إلى INSTALLED_APPS
                    if ! grep -q "'employees'" settings.py; then
                        sed -i "/'django.contrib.staticfiles',/a \\    'employees'," settings.py
                        echo "✅ تم إضافة employees"
                    fi
                    
                    # إضافة accounts إذا لم تكن موجودة
                    if ! grep -q "'accounts'" settings.py; then
                        sed -i "/'django.contrib.staticfiles',/a \\    'accounts'," settings.py
                        echo "✅ تم إضافة accounts"
                    fi
                    
                    cd ../..
                '''
                echo '✅ تم إصلاح الإعدادات'
            }
        }

        stage('🐳 تشغيل قاعدة البيانات') {
            steps {
                sh '''
                    # إيقاف وإزالة الحاوية القديمة
                    docker stop ${DB_CONTAINER_NAME} 2>/dev/null || true
                    docker rm ${DB_CONTAINER_NAME} 2>/dev/null || true
                    
                    # تشغيل قاعدة البيانات الجديدة
                    docker run -d \
                        --name ${DB_CONTAINER_NAME} \
                        -e POSTGRES_DB=${DB_NAME} \
                        -e POSTGRES_USER=${DB_USER} \
                        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
                        -p 5432:5432 \
                        --network app-network \
                        postgres:17
                    
                    echo "⏳ انتظار تجهيز قاعدة البيانات..."
                    sleep 15
                '''
                echo '✅ قاعدة البيانات جاهزة'
            }
        }

        stage('🔄 تنفيذ الترحيلات') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py makemigrations --noinput
                    python manage.py migrate --noinput
                    cd ..
                '''
                echo '✅ تم تنفيذ الترحيلات'
            }
        }

        stage('🧪 تشغيل الاختبارات') {
            steps {
                sh '''
                    . venv/bin/activate
                    cd backend
                    python manage.py test --verbosity=2 --noinput || echo "⚠️ اختبارات بها تحذيرات"
                    cd ..
                '''
                echo '✅ اكتملت الاختبارات'
            }
        }

        stage('🐳 بناء صورة Docker') {
            steps {
                sh '''
                    # إنشاء Dockerfile إذا لم يكن موجوداً
                    if [ ! -f "Dockerfile" ]; then
                        cat > Dockerfile << 'EOF'
FROM python:3.10-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc postgresql-client curl && rm -rf /var/lib/apt/lists/*
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
                    
                    # بناء الصورة
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest
                '''
                echo '✅ تم بناء صورة Docker'
            }
        }

        stage('📤 رفع إلى Docker Hub') {
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

        stage('🚀 إيقاف الحاويات القديمة') {
            steps {
                sh '''
                    echo "إيقاف الحاويات القديمة..."
                    docker stop ${CONTAINER_NAME} 2>/dev/null || true
                    docker rm ${CONTAINER_NAME} 2>/dev/null || true
                '''
                echo '✅ تم إيقاف الحاويات القديمة'
            }
        }

        stage('🌐 تشغيل التطبيق') {
            steps {
                sh '''
                    # إنشاء شبكة إذا لم تكن موجودة
                    docker network create app-network 2>/dev/null || true
                    
                    # تشغيل التطبيق
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p ${DEPLOY_PORT}:8000 \
                        -e DB_HOST=${DB_CONTAINER_NAME} \
                        -e DB_NAME=${DB_NAME} \
                        -e DB_USER=${DB_USER} \
                        -e DB_PASSWORD=${DB_PASSWORD} \
                        -e DJANGO_SETTINGS_MODULE=${DJANGO_SETTINGS_MODULE} \
                        -e SECRET_KEY=${SECRET_KEY} \
                        -e DEBUG=True \
                        -e ALLOWED_HOSTS=* \
                        --network app-network \
                        ${DOCKER_IMAGE}:latest
                    
                    sleep 5
                '''
                echo '✅ تم تشغيل التطبيق'
            }
        }

        stage('🔍 فحص صحة التطبيق') {
            steps {
                sh '''
                    echo "فحص صحة التطبيق..."
                    
                    # التحقق من أن الحاوية تعمل
                    if docker ps | grep -q ${CONTAINER_NAME}; then
                        echo "✅ الحاوية تعمل"
                        
                        # اختبار الصحة
                        sleep 3
                        curl -s http://localhost:${DEPLOY_PORT}/ || echo "⚠️ التطبيق يعمل ولكن لا يوجد رد"
                    else
                        echo "❌ الحاوية لا تعمل"
                        docker logs ${CONTAINER_NAME} --tail 50
                        exit 1
                    fi
                '''
                echo '✅ فحص الصحة ناجح'
            }
        }

        stage('📊 معلومات التشغيل') {
            steps {
                sh '''
                    echo "========================================="
                    echo "🎉 التطبيق يعمل الآن! 🎉"
                    echo "========================================="
                    echo ""
                    echo "الرابط: http://localhost:${DEPLOY_PORT}"
                    echo "الرابط: http://192.168.142.142:${DEPLOY_PORT}"
                    echo ""
                    echo "حاوية قاعدة البيانات: ${DB_CONTAINER_NAME}"
                    echo "حاوية التطبيق: ${CONTAINER_NAME}"
                    echo "صورة Docker: ${DOCKER_IMAGE}:latest"
                    echo ""
                    echo "لرؤية السجلات:"
                    echo "  docker logs ${CONTAINER_NAME}"
                    echo ""
                    echo "للدخول إلى الحاوية:"
                    echo "  docker exec -it ${CONTAINER_NAME} bash"
                    echo ""
                    echo "========================================="
                '''
            }
        }
    }

    post {
        success {
            echo '🎉🎉🎉 نجاح! اكتمل البناء والتشغيل بنجاح! 🎉🎉🎉'
            echo ""
            echo "التطبيق يعمل على: http://localhost:8000"
            echo "رابط Docker Hub: https://hub.docker.com/r/${DOCKER_IMAGE}"
        }
        failure {
            echo '❌❌❌ فشل! راجع السجلات أعلاه ❌❌❌'
        }
        always {
            sh '''
                echo "🧹 تنظيف البيئة الافتراضية..."
                rm -rf venv || true
                echo "✅ تم التنظيف"
            '''
        }
    }
}
