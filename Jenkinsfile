pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_NAME        = "sab4r/wso2am-custom"
        DOCKER_REGISTRY   = "docker.io"

        GITHUB_CREDS      = 'github-credentials'
        DOCKERHUB_CREDS    = 'dockerhub-credentials'

        REPO_OWNER        = 'WSO2-Project'
        APP_REPO_NAME     = 'wso2-apim-app'
        HELM_REPO_NAME    = 'wso2-apim-helm'
        HELM_REPO_BRANCH  = 'main'
        HELM_CHART_PATH   = 'wso2-chart'

        BASE_VERSION      = '4.7.0'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHA = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    env.BRANCH = env.BRANCH_NAME ?: sh(
                        script: "git rev-parse --abbrev-ref HEAD",
                        returnStdout: true
                    ).trim()

                    if (env.BRANCH == 'main') {
                        env.IMAGE_TAG  = "${env.BASE_VERSION}"
                        env.DEPLOY_ENV = "production"
                    } else if (env.BRANCH == 'develop') {
                        env.IMAGE_TAG  = "${env.BASE_VERSION}-dev-${env.GIT_SHA}"
                        env.DEPLOY_ENV = "staging"
                    } else if (env.BRANCH.startsWith('release/')) {
                        def releaseVersion = env.BRANCH.replace('release/', '')
                        env.IMAGE_TAG  = "${releaseVersion}-rc"
                        env.DEPLOY_ENV = "staging"
                    } else if (env.BRANCH.startsWith('hotfix/')) {
                        def hotfixVersion = env.BRANCH.replace('hotfix/', '')
                        env.IMAGE_TAG  = "${hotfixVersion}-hotfix-${env.GIT_SHA}"
                        env.DEPLOY_ENV = "staging"
                    } else {
                        env.IMAGE_TAG  = "${env.BASE_VERSION}-feat-${env.GIT_SHA}"
                        env.DEPLOY_ENV = "none"
                    }

                    currentBuild.displayName = "[${env.BRANCH}] ${IMAGE_NAME}:${env.IMAGE_TAG}"

                    echo """
                    Branch     : ${env.BRANCH}
                    Git SHA    : ${env.GIT_SHA}
                    Image Tag  : ${env.IMAGE_TAG}
                    Deploy Env : ${env.DEPLOY_ENV}
                    """
                }
            }
        }

        stage('Build Image') {
            steps {
                script {
                    echo "Building ${IMAGE_NAME}:${env.IMAGE_TAG}..."
                    docker.build(
                        "${IMAGE_NAME}:${env.IMAGE_TAG}",
                        "--no-cache --label git-sha=${env.GIT_SHA} --label branch=${env.BRANCH} ."
                    )
                }
            }
        }

        stage('Test Image') {
            steps {
                script {
                    sh "docker image inspect ${IMAGE_NAME}:${env.IMAGE_TAG}"

                    sh """
                        docker run --rm -d \
                            --name wso2-test-${env.GIT_SHA} \
                            -p 19443:9443 \
                            ${IMAGE_NAME}:${env.IMAGE_TAG} || true
                        sleep 10
                        docker stop wso2-test-${env.GIT_SHA} || true
                    """
                }
            }
        }

        stage('Push Image') {
            when {
                not { expression { env.BRANCH.startsWith('feature/') } }
            }
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", DOCKERHUB_CREDS) {
                        docker.image("${IMAGE_NAME}:${env.IMAGE_TAG}").push()
                        echo "Pushed: ${IMAGE_NAME}:${env.IMAGE_TAG}"

                        if (env.BRANCH == 'main') {
                            docker.image("${IMAGE_NAME}:${env.IMAGE_TAG}").push('latest')
                            echo "Pushed: ${IMAGE_NAME}:latest"
                        }
                    }
                }
            }
        }

        stage('Update Helm Repo') {
            when {
                expression {
                    env.BRANCH == 'main' ||
                    env.BRANCH == 'develop' ||
                    env.BRANCH.startsWith('release/') ||
                    env.BRANCH.startsWith('hotfix/')
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GITHUB_CREDS,
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh """
                        set -e

                        git config --global user.email "jenkins@inetum.com"
                        git config --global user.name "Jenkins CI"

                        rm -rf helm-repo-temp
                        git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/${REPO_OWNER}/${HELM_REPO_NAME}.git helm-repo-temp
                        cd helm-repo-temp/${HELM_CHART_PATH}

                        sed -i 's|^      tag:.*|      tag: "${env.IMAGE_TAG}"|' values.yaml

                        git add values.yaml
                        git commit -m "ci: update image tag to ${env.IMAGE_TAG} [env:${env.DEPLOY_ENV}] [skip ci]" || echo "No changes to commit"
                        git push origin ${HELM_REPO_BRANCH}
                    """
                    echo "Helm repo updated with tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Create Git Tag') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GITHUB_CREDS,
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh """
                        set -e
                        git fetch --tags
                        if git rev-parse "v${env.BASE_VERSION}" >/dev/null 2>&1; then
                            echo "Tag v${env.BASE_VERSION} already exists, skipping..."
                        else
                            git tag -a v${env.BASE_VERSION} -m "Release v${env.BASE_VERSION} - Built by Jenkins [Build #${BUILD_NUMBER}]"
                            git push https://${GIT_USER}:${GIT_TOKEN}@github.com/${REPO_OWNER}/${APP_REPO_NAME}.git v${env.BASE_VERSION}
                            echo "Created and pushed tag v${env.BASE_VERSION}"
                        fi
                    """
                }
            }
        }
    }

    post {
        success {
            echo """
PIPELINE SUCCESS
Branch     : ${env.BRANCH}
Image      : ${IMAGE_NAME}:${env.IMAGE_TAG}
Deploy Env : ${env.DEPLOY_ENV}
Build #    : ${BUILD_NUMBER}
"""
        }
        failure {
            echo """
PIPELINE FAILED
Branch     : ${env.BRANCH}
Image      : ${IMAGE_NAME}:${env.IMAGE_TAG}
Build #    : ${BUILD_NUMBER}
"""
        }
        always {
            sh "docker rmi ${IMAGE_NAME}:${env.IMAGE_TAG} || true"
            cleanWs()
        }
    }
}