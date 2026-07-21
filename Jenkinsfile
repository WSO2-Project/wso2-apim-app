final String comparatorRegex = 'REGEXP'
final String branchMaster = 'master'
final String branchDevelop = 'develop'

void runCheckedStep(String checkName, String title, Closure body) {
    String completed = 'COMPLETED'
    publishChecks name: checkName, title: title, status: 'IN_PROGRESS'
    try {
        body()
        publishChecks name: checkName, title: title,
                      status: completed, conclusion: 'SUCCESS'
    } catch (err) {
        publishChecks name: checkName, title: title,
                      status: completed, conclusion: 'FAILURE',
                      summary: "Failed: ${err.message}"
        throw err
    }
}

pipeline {
    agent any
    environment {
        IMAGE_NAME = 'sab4r/wso2am-custom'
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
    }
    stages {
        stage('Build') {
            steps {
                runCheckedStep('build', 'Build Docker image') {
                    echo "Build ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        stage('Push') {
            when {
                allOf {
                    not {
                        changeRequest()
                    }
                    anyOf {
                        branch branchDevelop
                        branch branchMaster
                        branch pattern: 'release/.*', comparator: comparatorRegex
                        branch pattern: 'hotfix/.*',  comparator: comparatorRegex
                    }
                }
            }
            steps {
                runCheckedStep('push', 'Push to Docker Hub') {
                    echo "Push ${IMAGE_NAME}:${IMAGE_TAG} to Docker Hub"
                }
            }
        }
        stage('Update Helm') {
            when {
                allOf {
                    not { changeRequest() }
                    anyOf {
                        branch branchDevelop
                        branch branchMaster
                    }
                }
            }
            steps {
                runCheckedStep('helm', 'Update Helm values') {
                    echo 'Update helm-repo values.yaml'
                }
            }
        }
    }

    post {
        always {
            echo "Build #${env.BUILD_NUMBER} finished on ${env.BRANCH_NAME}"
            cleanWs()
        }
        success {
            echo "Pipeline succeeded on ${env.BRANCH_NAME}"
        }
        failure {
            echo "Pipeline FAILED on ${env.BRANCH_NAME}"
        }
    }

}

