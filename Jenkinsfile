pipeline {
    agent any

    parameters {
        choice(name: 'REPO_NAME', choices: ['mule', 'mule_1'], description: 'Select MuleSoft Repo')
        string(name: 'BRANCH', defaultValue: 'main', description: 'Git branch')
        choice(name: 'ENV', choices: ['dev', 'qa', 'prod'], description: 'Deployment environment')
    }

    environment {
        GIT_URL = "https://github.com/samaharshareddy/${params.REPO_NAME}.git"
        MAVEN_OPTS = "-Dmaven.repo.local=.m2/repository"
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: "${params.BRANCH}",
                    url: "${GIT_URL}",
                    credentialsId: 'github-token'
            }
        }

        stage('Build MuleSoft Application') {
            steps {
                sh '''
                  mvn clean package -DskipTests
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                  mvn test
                '''
            }
        }

        stage('Package Artifact') {
            steps {
                sh '''
                  ls -lh target/
                '''
            }
        }

        stage('Deploy (Optional)') {
            when {
                expression { params.ENV != 'dev' }
            }
            steps {
                echo "Deploying ${params.REPO_NAME} to ${params.ENV}"
                // Add Anypoint CLI / CloudHub deploy here
            }
        }
    }

    post {
        success {
            echo "Build successful for ${params.REPO_NAME}"
        }
        failure {
            echo "Build failed for ${params.REPO_NAME}"
        }
    }
}

