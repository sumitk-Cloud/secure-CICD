pipeline {
    agent any

    parameters {
        choice(name: 'SEVERITY_THRESHOLD',
               choices: ['HIGH,CRITICAL', 'CRITICAL'],
               description: 'Severities that fail the build')
    }

    environment {
        // TODO: replace with your Docker Hub username
        IMAGE_NAME = 'YOUR_DOCKERHUB_USER/secure-flask-app'
        IMAGE_TAG  = "${BUILD_NUMBER}"
        FULL_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $FULL_IMAGE .'
            }
        }

        stage('Trivy Scan - Generate Report') {
            // Full report of all severities; never fails the build
            steps {
                sh '''
                    mkdir -p reports
                    trivy image --no-progress --exit-code 0 \
                        --severity LOW,MEDIUM,HIGH,CRITICAL \
                        --format table --output reports/trivy-report.txt $FULL_IMAGE
                    trivy image --no-progress --exit-code 0 \
                        --format json --output reports/trivy-report.json $FULL_IMAGE
                '''
            }
        }

        stage('Security Gate') {
            // Fails the pipeline if findings at/above the threshold exist
            steps {
                sh '''
                    trivy image --no-progress \
                        --severity $SEVERITY_THRESHOLD \
                        --ignore-unfixed \
                        --exit-code 1 \
                        $FULL_IMAGE
                '''
            }
        }

        stage('Push to Registry') {
            // Only reached if the gate passed
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push $FULL_IMAGE
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        sed "s|IMAGE_PLACEHOLDER|$FULL_IMAGE|g" k8s/deployment.yaml | kubectl apply -f -
                        kubectl apply -f k8s/service.yaml
                        kubectl rollout status deployment/secure-flask-app --timeout=120s
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh '''
                        kubectl get pods -l app=secure-flask-app
                        kubectl get svc secure-flask-app-svc
                        echo "Deployed image:"
                        kubectl get deployment secure-flask-app \
                          -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/*', allowEmptyArchive: true
            sh 'docker rmi $FULL_IMAGE || true'
        }
        success { echo 'Image passed the security gate and was deployed.' }
        failure { echo 'Pipeline FAILED. Check the Trivy report. If the gate failed, nothing was pushed or deployed.' }
    }
}
