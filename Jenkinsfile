pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_NAME     = "sab4r/wso2am-custom"
        DOCKER_REGISTRY = "docker.io"

        GITHUB_CREDS   = "github-credentials"
        DOCKER_CREDS   = "dockerhub-credentials"

        REPO_OWNER    = "WSO2-Project"
        APP_REPO      = "wso2-apim-app"
        HELM_REPO     = "wso2-apim-helm"

        HELM_BRANCH   = "main"
        HELM_PATH     = "wso2-chart"

        BASE_VERSION  = "4.7.0"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHA = bat(
    script: '@git rev-parse --short HEAD',
    returnStdout: true
).trim().readLines().last().trim()

env.BRANCH = bat(
    script: '@git rev-parse --abbrev-ref HEAD',
    returnStdout: true
).trim().readLines().last().trim()

if (!env.BRANCH || env.BRANCH == "HEAD" || env.BRANCH == "null") {
    env.BRANCH = "develop"
}

echo "Branch detected: '${env.BRANCH}'"
echo "GIT_SHA detected: '${env.GIT_SHA}'"

                    if (env.BRANCH == "main") {
                        env.IMAGE_TAG = "${BASE_VERSION}"
                        env.DEPLOY_ENV = "production"
                    } else if (env.BRANCH == "develop") {
                        env.IMAGE_TAG = "${BASE_VERSION}-dev-${env.GIT_SHA}"
                        env.DEPLOY_ENV = "staging"
                    } else if (env.BRANCH.startsWith("release/")) {
                        def version = env.BRANCH.replace("release/", "")
                        env.IMAGE_TAG = "${version}-rc"
                        env.DEPLOY_ENV = "staging"
                    } else if (env.BRANCH.startsWith("hotfix/")) {
                        def version = env.BRANCH.replace("hotfix/", "")
                        env.IMAGE_TAG = "${version}-hotfix-${env.GIT_SHA}"
                        env.DEPLOY_ENV = "staging"
                    } else {
                        env.IMAGE_TAG = "${BASE_VERSION}-feature-${env.GIT_SHA}"
                        env.DEPLOY_ENV = "none"
                    }

                    currentBuild.displayName = "[${env.BRANCH}] ${env.IMAGE_TAG}"

                    echo """

WSO2 API MANAGER CI/CD

Branch        : ${env.BRANCH}
Commit        : ${env.GIT_SHA}
Docker Image  : ${IMAGE_NAME}
Docker Tag    : ${env.IMAGE_TAG}
Environment   : ${env.DEPLOY_ENV}

"""
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                bat """
                docker build ^
                  --no-cache ^
                  --label git-sha=${env.GIT_SHA} ^
                  --label branch=${env.BRANCH} ^
                  -t ${IMAGE_NAME}:${env.IMAGE_TAG} .
                """
            }
        }

        stage('Inspect Image') {
            steps {
                bat """
                docker image inspect ${IMAGE_NAME}:${env.IMAGE_TAG}
                """
            }
        }

        stage('Smoke Test') {
            steps {
                bat """
                docker rm -f wso2-test-${env.GIT_SHA} 2>nul

                docker run -d ^
                  --name wso2-test-${env.GIT_SHA} ^
                  -p 19443:9443 ^
                  ${IMAGE_NAME}:${env.IMAGE_TAG}

                timeout /t 20 /nobreak >nul

                docker logs wso2-test-${env.GIT_SHA}

                docker stop wso2-test-${env.GIT_SHA}
                docker rm wso2-test-${env.GIT_SHA}
                """
            }
        }

        stage('Push Docker Image') {
            when {
                expression {
                    env.BRANCH == "develop" ||
                    env.BRANCH == "main" ||
                    env.BRANCH.startsWith("release/") ||
                    env.BRANCH.startsWith("hotfix/")
                }
            }
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", DOCKER_CREDS) {
                        docker.image("${IMAGE_NAME}:${env.IMAGE_TAG}").push()
                        echo "Docker image pushed: ${IMAGE_NAME}:${env.IMAGE_TAG}"

                        if (env.BRANCH == "main") {
                            docker.image("${IMAGE_NAME}:${env.IMAGE_TAG}").push("latest")
                            echo "Docker image pushed: ${IMAGE_NAME}:latest"
                        }
                    }
                }
            }
        }

        stage('Update Helm Repository') {
            when {
                expression {
                    env.BRANCH == "develop" ||
                    env.BRANCH == "main" ||
                    env.BRANCH.startsWith("release/") ||
                    env.BRANCH.startsWith("hotfix/")
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GITHUB_CREDS,
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    bat """
                    git config --global user.name "Jenkins"
                    git config --global user.email "jenkins@company.com"

                    if exist helm-repo-temp rmdir /S /Q helm-repo-temp

                    git clone https://%GIT_USER%:%GIT_TOKEN%@github.com/${REPO_OWNER}/${HELM_REPO}.git helm-repo-temp
                    cd helm-repo-temp
                    git checkout ${HELM_BRANCH}

                    powershell -NoProfile -Command ^
                      "(Get-Content '${HELM_PATH}\\values.yaml') -replace 'tag:.*','tag: ${env.IMAGE_TAG}' | Set-Content '${HELM_PATH}\\values.yaml'"

                    git add ${HELM_PATH}\\values.yaml

                    git diff --cached --quiet
                    if errorlevel 1 (
                        git commit -m \"ci: update image tag ${env.IMAGE_TAG} [skip ci]\"
                        git push origin ${HELM_BRANCH}
                    ) else (
                        echo No changes detected.
                    )
                    """
                    echo "Helm repository updated."
                }
            }
        }

        stage('Create Git Tag') {
            when {
                expression { env.BRANCH == "main" }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: GITHUB_CREDS,
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    bat """
                    git fetch --tags
                    git ls-remote --tags origin v${BASE_VERSION} >nul 2>nul
                    if errorlevel 1 (
                        git tag -a v${BASE_VERSION} -m "Release ${BASE_VERSION}"
                        git push https://%GIT_USER%:%GIT_TOKEN%@github.com/${REPO_OWNER}/${APP_REPO}.git v${BASE_VERSION}
                        echo Git tag v${BASE_VERSION} created.
                    ) else (
                        echo Git tag already exists.
                    )
                    """
                }
            }
        }
    }

    post {
        success {
            echo """

PIPELINE SUCCESS
Branch       : ${env.BRANCH}
Commit       : ${env.GIT_SHA}
Image        : ${IMAGE_NAME}:${env.IMAGE_TAG}
Environment  : ${env.DEPLOY_ENV}
Build Number : ${BUILD_NUMBER}

"""
        }
        failure {
            echo """

PIPELINE FAILED
Branch       : ${env.BRANCH}
Commit       : ${env.GIT_SHA}
Image        : ${IMAGE_NAME}:${env.IMAGE_TAG}
Build Number : ${BUILD_NUMBER}

"""
        }
        always {
            bat """
            docker rm -f wso2-test-${env.GIT_SHA} 2>nul
            docker rmi ${IMAGE_NAME}:${env.IMAGE_TAG} 2>nul
            exit /b 0
            """
            cleanWs()
        }
    }
}