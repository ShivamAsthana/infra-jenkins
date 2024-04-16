pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        AWS_DEFAULT_REGION = "us-east-1"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/ShivamAsthana/infra-jenkins.git'
            }
        }
    
        stage ("Terraform Init") {
            steps {
                sh "terraform init" 
            }
        }
  
        stage ("Terraform Plan") {
            steps {
                sh "terraform plan" 
            }
        }
        
        stage ("Terraform Apply") {
            steps {
                sh 'terraform ${action} --auto-approve' 
           }
        }
        
        stage("Deploy to EKS") {
            when {
                expression { params.apply }
            }
            steps {
                withAWS(credentials: ['aws-credentials-id', 'aws-credentials-secret']) {
                    sh "aws eks update-kubeconfig --name eks_cluster"
                    sh "kubectl apply -f deployment.yml"
                }
            }
        }
    }
}
