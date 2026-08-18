final String comparatorRegex   = 'REGEXP'
final String branchMain        = 'main'
final String branchDevelop     = 'develop'
final String releaseBranchPattern = /^release\/(\d+\.\d+\.\d+)$/
final String hotfixBranchPattern  = /^hotfix\/(\d+\.\d+\.\d+)$/

// Docker tags may not contain '+' -> replace with '_'
String dockerTag(String version) {
    return version.replace('+', '_')
}

// Splits "4.7.0+0.4.0-RC1" into [wso2: '4.7.0', custom: '0.4.0', tag: 'RC1']
Map parseVersion(String raw) {
    def m = raw.trim() =~ /^(\d+\.\d+\.\d+)\+(\d+\.\d+\.\d+)(?:-(.+))?$/
    if (!m) {
        error("VERSION file malformed: '${raw}' (expected <WSO2>+<MAJOR.MINOR.PATCH>[-TAG])")
    }
    return [wso2: m[0][1], custom: m[0][2], tag: m[0][3] ?: '']
}

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

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_NAME      = "sab4r/wso2am-custom"
        DOCKER_REGISTRY = "index.docker.io/v1/"
        GITHUB_CREDS    = "github-credentials"
        GITHUB_APP      = "github-app-jenkins"
        DOCKER_CREDS    = "dockerhub-credentials"
        REPO_OWNER      = "WSO2-Project"
        APP_REPO        = "wso2-apim-app"
        HELM_REPO       = "wso2-apim-helm"
        HELM_BRANCH     = "main"
        HELM_PATH       = "wso2-chart"
    }

    stages {

        stage('Init') {
            steps {
                script {
                    runCheckedStep('init', 'Resolve version & image tag') {

                        env.GIT_SHA = sh(
                            script: 'git rev-parse --short HEAD',
                            returnStdout: true
                        ).trim()

                        env.RAW_VERSION = readFile('VERSION').trim()
                        def v = parseVersion(env.RAW_VERSION)
                        env.WSO2_VERSION   = v.wso2
                        env.CUSTOM_VERSION = v.custom
                        env.VERSION_TAG    = v.tag

                        // release/* resolves its tag later in 'Compute RC tag'
                        if (env.BRANCH_NAME ==~ releaseBranchPattern) {
                            env.DEPLOY_ENV = 'staging'
                            echo "Release branch detected - IMAGE_TAG deferred to 'Compute RC tag'"

                        } else if (env.BRANCH_NAME == branchMain) {
                            if (v.tag) {
                                error("main must carry a final VERSION, got pre-release tag '-${v.tag}'")
                            }
                            env.IMAGE_TAG  = dockerTag("${v.wso2}+${v.custom}")
                            env.DEPLOY_ENV = 'production'

                        } else if (env.BRANCH_NAME == branchDevelop || env.BRANCH_NAME ==~ hotfixBranchPattern) {
                            if (v.tag != 'SNAPSHOT') {
                                error("${env.BRANCH_NAME} expects a -SNAPSHOT VERSION, got '-${v.tag ?: '(none)'}'")
                            }
                            env.IMAGE_TAG  = dockerTag("${v.wso2}+${v.custom}-SNAPSHOT-${env.GIT_SHA}")
                            env.DEPLOY_ENV = 'staging'

                        } else if (env.CHANGE_ID) {
                            env.IMAGE_TAG  = dockerTag("${v.wso2}+${v.custom}-pr${env.CHANGE_ID}-${env.GIT_SHA}")
                            env.DEPLOY_ENV = 'none'

                        } else {
                            env.IMAGE_TAG  = dockerTag("${v.wso2}+${v.custom}-${env.GIT_SHA}")
                            env.DEPLOY_ENV = 'none'
                        }

                        if (env.IMAGE_TAG) {
                            currentBuild.displayName = "[${env.BRANCH_NAME}] ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                        }

                        echo """
                        Branch      : ${env.BRANCH_NAME}
                        Git SHA     : ${env.GIT_SHA}
                        VERSION     : ${env.RAW_VERSION}
                        Image Tag   : ${env.IMAGE_TAG ?: '(deferred)'}
                        Deploy Env  : ${env.DEPLOY_ENV}
                        """
                    }
                }
            }
        }

        stage('Compute RC tag') {
            when {
                allOf {
                    not { changeRequest() }
                    branch pattern: 'release/.*', comparator: comparatorRegex
                }
            }
            steps {
                script {
                    runCheckedStep('rc-tag', 'Compute, commit & create RC tag') {
                        def m = env.BRANCH_NAME =~ releaseBranchPattern
                        if (!m) { error("Branch doesn't match release/X.Y.Z: ${env.BRANCH_NAME}") }
                        env.RELEASE_VERSION = m[0][1]

                        if (env.RELEASE_VERSION != env.CUSTOM_VERSION) {
                            error("Branch version (${env.RELEASE_VERSION}) != VERSION file custom version (${env.CUSTOM_VERSION})")
                        }

                        withCredentials([gitUsernamePassword(credentialsId: env.GITHUB_APP)]) {
                            sh 'git fetch --tags --force'

                            // Match both legacy '-rc.N' and current '-RCN'
                            def existing = sh(
                                script: "git tag -l 'v${env.RELEASE_VERSION}-RC*' 'v${env.RELEASE_VERSION}-rc.*'",
                                returnStdout: true
                            ).trim()

                            int nextRc = 1
                            if (existing) {
                                int highest = 0
                                existing.readLines().each { line ->
                                    def rc = line.trim() =~ /-[Rr][Cc]\.?(\d+)$/
                                    if (rc) {
                                        int n = rc[0][1] as int
                                        if (n > highest) { highest = n }
                                    }
                                }
                                nextRc = highest + 1
                            }

                            env.RC_NUMBER  = "${nextRc}"
                            env.RC_TAG     = "v${env.RELEASE_VERSION}-RC${nextRc}"
                            env.NEW_VERSION = "${env.WSO2_VERSION}+${env.RELEASE_VERSION}-RC${nextRc}"
                            env.IMAGE_TAG   = dockerTag(env.NEW_VERSION)

                            writeFile file: 'VERSION', text: "${env.NEW_VERSION}\n"

                            sh """
                                git config user.email 'jenkins-ci@wso2-project'
                                git config user.name 'Jenkins CI'

                                git add VERSION
                                git commit -m 'ci: bump VERSION to ${env.NEW_VERSION} [skip ci]'
                                git tag -a ${env.RC_TAG} -m 'Release candidate ${nextRc} for ${env.RELEASE_VERSION}'

                                git push origin HEAD:${env.BRANCH_NAME}
                                git push origin ${env.RC_TAG}
                            """
                        }

                        currentBuild.displayName = "[${env.BRANCH_NAME}] ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                        echo "RC tag ${env.RC_TAG} created - image tag ${env.IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    runCheckedStep('build', 'Build Docker image') {
                        echo "Build ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                        sh """
                        docker build \\
                          --no-cache \\
                          --label git-sha=${env.GIT_SHA} \\
                          --label branch=${env.BRANCH_NAME} \\
                          --label version=${env.RAW_VERSION} \\
                          -t ${env.IMAGE_NAME}:${env.IMAGE_TAG} .
                        """
                    }
                }
            }
        }

        stage('Inspect Image') {
            steps {
                script {
                    runCheckedStep('inspect', 'Inspect Docker image') {
                        sh "docker image inspect ${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Push') {
            when {
                allOf {
                    not { changeRequest() }
                    anyOf {
                        branch branchDevelop
                        branch branchMain
                        branch pattern: 'feature/.*', comparator: comparatorRegex
                        branch pattern: 'release/.*', comparator: comparatorRegex
                        branch pattern: 'hotfix/.*',  comparator: comparatorRegex
                    }
                }
            }
            steps {
                script {
                    runCheckedStep('push', 'Push to Docker Hub') {
                        docker.withRegistry("https://${env.DOCKER_REGISTRY}", env.DOCKER_CREDS) {
                            docker.image("${env.IMAGE_NAME}:${env.IMAGE_TAG}").push()
                            echo "Docker image pushed: ${env.IMAGE_NAME}:${env.IMAGE_TAG}"

                            if (env.BRANCH_NAME == branchMain) {
                                docker.image("${env.IMAGE_NAME}:${env.IMAGE_TAG}").push('latest')
                                echo "Docker image pushed: ${env.IMAGE_NAME}:latest"
                            }
                        }
                    }
                }
            }
        }

        stage('Update Helm') {
            when {
                allOf {
                    not { changeRequest() }
                    anyOf {
                        branch branchDevelop
                        branch branchMain
                        branch pattern: 'feature/.*', comparator: comparatorRegex
                    }
                }
            }
            steps {
                script {
                    runCheckedStep('helm', 'Update Helm values') {
                        echo 'Update helm-repo values.yaml'

                        withCredentials([usernamePassword(
                            credentialsId: env.GITHUB_CREDS,
                            usernameVariable: 'GIT_USER',
                            passwordVariable: 'GIT_TOKEN'
                        )]) {
                            sh """
                            git config --global user.name "Jenkins"
                            git config --global user.email "jenkins@company.com"

                            rm -rf helm-repo-temp

                            git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/${env.REPO_OWNER}/${env.HELM_REPO}.git helm-repo-temp
                            cd helm-repo-temp
                            git checkout ${env.HELM_BRANCH}

                            sed -i 's|tag:.*|tag: ${env.IMAGE_TAG}|' ${env.HELM_PATH}/values.yaml
                            sed -i 's|tag:.*|tag: ${env.IMAGE_TAG}|' ${env.HELM_PATH}/values-gateway.yml

                            git add ${env.HELM_PATH}/values.yaml
                            git add ${env.HELM_PATH}/values-gateway.yml

                            if ! git diff --cached --quiet; then
                                git commit -m "ci: update image tag ${env.IMAGE_TAG} [skip ci]"
                                git push origin ${env.HELM_BRANCH}
                            else
                                echo 'No changes detected.'
                            fi
                            """
                            echo 'Helm repository updated.'
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            echo """
            PIPELINE SUCCESS
            Branch       : ${env.BRANCH_NAME}
            Commit       : ${env.GIT_SHA ?: 'n/a'}
            Version      : ${env.RAW_VERSION ?: 'n/a'}
            Image        : ${env.IMAGE_NAME}:${env.IMAGE_TAG ?: 'n/a'}
            Build Number : ${env.BUILD_NUMBER}
            """
        }
        failure {
            echo """
            PIPELINE FAILED
            Branch       : ${env.BRANCH_NAME}
            Commit       : ${env.GIT_SHA ?: 'n/a'}
            Version      : ${env.RAW_VERSION ?: 'n/a'}
            Image        : ${env.IMAGE_NAME}:${env.IMAGE_TAG ?: 'n/a'}
            Build Number : ${env.BUILD_NUMBER}
            """
        }
        always {
            script {
                if (env.GIT_SHA) {
                    sh "docker rm -f wso2-test-${env.GIT_SHA} 2>/dev/null || true"
                }
                if (env.IMAGE_TAG) {
                    sh "docker rmi ${env.IMAGE_NAME}:${env.IMAGE_TAG} 2>/dev/null || true"
                }
            }
            cleanWs()
        }
    }
}
