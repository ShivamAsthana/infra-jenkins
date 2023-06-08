pipeline {
    agent any
   
    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS')
        AWS_DEFAULT_REGION = "eu-west-2"
    }
    stages {
        stage('Checkout') {
            steps {
           git branch: 'main', url: 'https://github.com/abdurahim50/infra-jenkins.git'
  
            }
        }
    
        stage ("terraform init") {
            steps {
                sh "terraform init" 
            }
        }
  
        stage ("plan") {
            steps {
                sh "terraform plan" 
            }
        }
        stage (" Action") {
            steps {
                sh 'terraform ${action} --auto-approve' 
           }
        }
        stage("Deploy to EKS") {
            when {
                expression { params.apply }
            }
            steps {
                  sh "aws eks update-kubeconfig --name eks_cluster"
                   sh "kubectl apply -f deployment.yml"
             }
        }
    }
}
   
    
