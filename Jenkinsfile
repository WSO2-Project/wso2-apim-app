final String comparatorRegex = 'REGEXP'
final String branchMaster = 'master'
final String branchDevelop = 'develop'
final String releaseBranchPattern = /^release\/(\d+\.\d+\.\d+)$/

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
        GITHUB_APP = 'github-app-jenkins'
    }
    stages {
        stage('Compute RC tag') {
            when {
                allOf {
                    not { changeRequest() }
                    branch pattern: 'release/.*', comparator: comparatorRegex
                }
            }
            steps {
                script {
                    runCheckedStep('rc-tag', 'Compute & create RC tag') {
                        // Validate version from branch
                        def m = env.BRANCH_NAME =~ releaseBranchPattern
                        if (!m) { error("Branch name doesn't match release/X.Y.Z: ${env.BRANCH_NAME}") }
                        env.RELEASE_VERSION = m[0][1]

                        // Compute RC tag
                        withCredentials([gitUsernamePassword(credentialsId: env.GITHUB_APP)]) {
                            sh 'git fetch --tags --force'
                            def existing = sh(
                                script: "git tag -l 'v${env.RELEASE_VERSION}-rc.*' | sort -V",
                                returnStdout: true
                            ).trim()

                            int nextRc = 1
                            if (existing) {
                                def last = existing.readLines().last()
                                nextRc = ((last =~ /-rc\.(\d+)$/)[0][1] as int) + 1
                            }
                            env.RC_NUMBER = "${nextRc}"
                            env.RC_TAG = "v${env.RELEASE_VERSION}-rc.${nextRc}"

                            sh """
                                git config user.email 'jenkins-ci@wso2-project'
                                git config user.name 'Jenkins CI'
                                git tag -a ${env.RC_TAG} -m 'Release candidate ${nextRc} for ${env.RELEASE_VERSION}'
                                git push origin ${env.RC_TAG}
                            """
                        }
                        env.IMAGE_TAG = env.RC_TAG
                    }
                }
    
            }
        }

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
