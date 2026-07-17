pipeline {
    agent any
    environment {
        IMAGE_NAME = "sab4r/wso2am-custom"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Build')    { steps { echo 'Build Docker image' } }
        stage('Push')     { steps { echo 'Push to DockerHub' } }
        stage('Update Helm') { steps { echo 'Update helm-repo values.yaml' } }
    }
}