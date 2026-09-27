pipeline {
    agent any

    environment {
        TF_DIR = "environments/dev"
        AWS_DEFAULT_REGION = "us-east-1"
    }

    stages {

        stage('Lint') {
            steps {
                dir("${TF_DIR}") {
                    sh 'terraform fmt -check -recursive'
                    sh 'terraform init -backend=false'
                    sh 'terraform validate'
                }
            }
        }

        stage('Plan') {
            steps {
                dir("${TF_DIR}") {
                    // terraform.tfvars is never committed to the repo
                    withCredentials([file(credentialsId: 'tf-tfvars', variable: 'TFVARS_FILE')]) {
                        sh '''#!/bin/bash
                            set -euo pipefail
                            cp "$TFVARS_FILE" terraform.tfvars
                            terraform init -reconfigure
                            terraform plan -no-color -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Manual Approval') {
            steps {
                input message: 'Apply this Terraform plan?', ok: 'Apply'
            }
        }

        stage('Apply') {
            steps {
                dir("${TF_DIR}") {
                    sh 'terraform apply tfplan'
                }
            }
        }

        stage('Post-Apply Health Check') {
            steps {
                dir("${TF_DIR}") {
                    sh '''#!/bin/bash
                        set -euo pipefail
                        aws eks update-kubeconfig --name cost-optimization-dev --region us-east-1
                        echo "=== Verifying sample workload rollout ==="
                        kubectl rollout status deployment/sample-web-deployment -n sample-workloads --timeout=180s
                        echo "=== Workload healthy ==="
                    '''
                }
            }
        }
    }

    post {
        always {
            dir("${TF_DIR}") {
                sh 'rm -f terraform.tfvars tfplan'
            }
        }
        failure {
            echo 'Pipeline failed (check the stage logs above)'
        }
        success {
            echo 'Pipeline completed successfully.'
        }
    }
}