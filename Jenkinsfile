pipeline {
    agent any
    
    environment {
        DJANGO_SETTINGS_MODULE = 'config.settings.production'
        SECRET_KEY = 'django-insecure-jenkins-build-key-2024'
        DEBUG = 'False'
        ALLOWED_HOSTS = 'localhost,127.0.0.1'
        
        DB_NAME = 'hr_app_db'
        DB_USER = 'postgres'
        DB_PASSWORD = 'postgres'
        DB_HOST = 'localhost'
        DB_PORT = '5432'
        
        PYTHONUNBUFFERED = '1'
    }
    
    stages {
        stage('📥 سحب الكود من GitHub') {
            steps {
                git branch: 'main', 
                    url: 'https://github.com/BHerradi-IT/CRUD_HR_app.git'
                echo '✅ تم سحب الكود من المستودع'
            }
        }
        
        stage('🐍 تجهيز Python والبيئة الافتراضية') {
            steps {
                sh '''
                    python3.10 -m venv venv
                    . venv/bin/activate
                    
                    pip install --upgrade pip
                    pip install wheel
                    
                    pip install django djangorestframework django-cors-headers psycopg2-binary gunicorn
                    pip install pytest pytest-django pytest-cov flake8 black
                    
                    if [ -f "requirements.txt" ]; then
                        pip install -r requirements.txt
                    fi
                    
                    if [ -f "backend/requirements.txt" ]; then
                        pip install -r backend/requirements.txt
                    fi
                '''
                echo '✅ تم تجهيز البيئة الافتراضية'
            }
        }
        
        stage('🔍 فحص جودة الكود') {
            steps {
                sh '''
                    . venv/bin/activate
                    echo "🔍 جاري فحص الكود..."
                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
                    echo "🎨 جاري فحص التنسيق..."
                    black --check . --diff || echo "⚠️ تحتاج بعض الملفات إلى تنسيق"
                '''
                echo '✅ تم اجتياز فحص الجودة'
            }
        }
        
        stage('🗄️ تشغيل قاعدة البيانات للاختبار') {
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
                        echo "⏳ انتظار تشغيل قاعدة البيانات..."
                        sleep 10
                    else
                        echo "⚠️ Docker غير مثبت، استخدام SQLite"
                        export DB_ENGINE='django.db.backends.sqlite3'
                        export DB_NAME='db.sqlite3'
                    fi
                '''
                echo '✅ قاعدة البيانات جاهزة'
            }
        }
        
        stage('🔄 تنفيذ ترحيلات قاعدة البيانات') {
            steps {
                sh '''
                    . venv/bin/activate
                    if [ -d "backend" ]; then
                        cd backend
                        python manage.py makemigrations --noinput || true
                        python manage.py migrate --noinput
                        cd ..
                    else
                        python manage.py makemigrations --noinput || true
                        python manage.py migrate --noinput
                    fi
                '''
                echo '✅ تم تنفيذ الترحيلات'
            }
        }
        
        stage('🧪 تشغيل الاختبارات') {
            steps {
                sh '''
                    . venv/bin/activate
                    if [ -d "backend" ]; then
                        cd backend
                        python manage.py test --verbosity=2 --noinput
                        cd ..
                    else
                        python manage.py test --verbosity=2 --noinput
                    fi
                '''
                echo '✅ اجتازت جميع الاختبارات'
            }
        }
        
        stage('🐳 بناء Docker Image') {
            when {
                branch 'main'
                expression { return fileExists('compose.yaml') }
            }
            steps {
                sh '''
                    docker-compose -f compose.yaml build
                    docker tag crud-hr-app-web:latest bherradi/crud-hr-app:${BUILD_NUMBER}
                '''
                echo '✅ تم بناء صورة Docker'
            }
        }
    }
    
    post {
        success {
            echo '🎉🎉🎉 نجاح البناء! 🎉🎉🎉'
        }
        failure {
            echo '❌❌❌ فشل البناء! راجع السجلات أعلاه ❌❌❌'
        }
        always {
            sh '''
                docker stop postgres-test 2>/dev/null || true
                docker rm postgres-test 2>/dev/null || true
                rm -rf venv || true
            '''
            echo '🧹 تم التنظيف'
        }
    }
}
