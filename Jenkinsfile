pipeline {
    agent any
	tools {
		jdk 'JDK17'
	}
    environment {
        EMAIL_RECIPIENTS = 'frederic.tischler2@gmail.com'
        DEMO_API_TOKEN   = credentials('demo-api-token')
        NEXUS_PASSWORD   = credentials('nexus-admin-password')
        NEXUS_REGISTRY   = 'localhost:5000'

        // Docker Compose deploy variables
        MONGODB_ROOT_USERNAME          = credentials('mongodb-root-username')
        MONGODB_ROOT_PASSWORD          = credentials('mongodb-root-password')
        USER_SERVICE_MONGODB_URI       = credentials('user-service-mongodb-uri')
        PRODUCT_SERVICE_MONGODB_URI    = credentials('product-service-mongodb-uri')
        MEDIA_SERVICE_MONGODB_URI      = credentials('media-service-mongodb-uri')
        ORDER_SERVICE_MONGODB_URI      = credentials('order-service-mongodb-uri')
        JWT_SECRET                     = credentials('jwt-secret')
        SERVER_SSL_KEY_STORE_PASSWORD  = credentials('ssl-keystore-password')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build_Backend') {
            steps {
                dir('backend') {
                    sh 'mvn -B clean package -DskipTests -s ../settings.xml'
                }
            }
        }
        stage('Test_Backend') {
            steps {
                dir('backend') {
                    sh 'mvn -B test -s ../settings.xml'
                }
            }
        }
        stage('Build_Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm run build -- --configuration production'
                }
            }
        }
        stage('Test_Frontend') {
            steps {
                dir('frontend') {
                    sh 'npm test -- --watch=false --browsers=ChromeHeadless'
                }
            }
        }
        stage('Publish_Maven_Artifacts') {
            steps {
                dir('backend') {
                    sh 'mvn -B deploy -DskipTests -s ../settings.xml'
                }
            }
        }
        stage('Build_Push_Docker_Images') {
            steps {
                script {
                    def imageVersion = sh(
                        returnStdout: true,
                        script: 'cd backend && mvn help:evaluate -Dexpression=project.version -q -DforceStdout -s ../settings.xml'
                    ).trim() + "-${env.BUILD_NUMBER}"

                    sh "echo \"\$NEXUS_PASSWORD\" | docker login \"\$NEXUS_REGISTRY\" -u admin --password-stdin"

                    ['user-service', 'product-service', 'media-service', 'order-service'].each { svc ->
                        sh """
                            docker build \\
                                --network=host \\
                                --build-arg NEXUS_PASSWORD="\$NEXUS_PASSWORD" \\
                                -f backend/${svc}/Dockerfile \\
                                -t "\$NEXUS_REGISTRY/ecommerce/${svc}:${imageVersion}" \\
                                -t "\$NEXUS_REGISTRY/ecommerce/${svc}:latest" \\
                                .
                            docker push "\$NEXUS_REGISTRY/ecommerce/${svc}:${imageVersion}"
                            docker push "\$NEXUS_REGISTRY/ecommerce/${svc}:latest"
                        """
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                dir('.') {
                    sh '''#!/bin/bash
set -euo pipefail
cleanup_containers() {
    local compose_file="$1"
    [[ -f "$compose_file" ]] || return 0
    local names
    names=$(grep -E '^[[:space:]]*container_name:' "$compose_file" | sed -E 's/^[[:space:]]*container_name:[[:space:]]*//' | tr -d '"' || true)
    [[ -z "${names:-}" ]] && return 0
    while IFS= read -r cname; do
        [[ -z "$cname" ]] && continue
        docker rm -f "$cname" >/dev/null 2>&1 || true
    done <<< "$names"
}

docker compose down --remove-orphans || true
cleanup_containers "docker-compose.yml"
docker compose up -d --build

echo "Using secured API token for deployment (valeur masquée dans les logs)"
# Exemple d'utilisation : curl -H "Authorization: Bearer $DEMO_API_TOKEN" ...
'''
                }
            }
            post {
                failure {
                    dir('.') {
                        sh '''#!/bin/bash
set -euo pipefail
cleanup_containers() {
    local compose_file="$1"
    [[ -f "$compose_file" ]] || return 0
    local names
    names=$(grep -E '^[[:space:]]*container_name:' "$compose_file" | sed -E 's/^[[:space:]]*container_name:[[:space:]]*//' | tr -d '"' || true)
    [[ -z "${names:-}" ]] && return 0
    while IFS= read -r cname; do
        [[ -z "$cname" ]] && continue
        docker rm -f "$cname" >/dev/null 2>&1 || true
    done <<< "$names"
}

docker compose down --remove-orphans || true
cleanup_containers "docker-compose.stable.yml"
docker compose -f docker-compose.stable.yml up -d --build
'''
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Build SUCCESS'
            mail(
                to: env.EMAIL_RECIPIENTS,
                subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """Build SUCCESS

Job      : ${env.JOB_NAME}
Build    : #${env.BUILD_NUMBER}
Result   : ${currentBuild.currentResult}
URL      : ${env.BUILD_URL}
Nexus    : http://localhost:8091
"""
            )
        }
        failure {
            echo 'Build FAILURE'
            mail(
                to: env.EMAIL_RECIPIENTS,
                subject: "FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """Build FAILURE

Job      : ${env.JOB_NAME}
Build    : #${env.BUILD_NUMBER}
Result   : ${currentBuild.currentResult}
URL      : ${env.BUILD_URL}
"""
            )
        }
    }
}
