
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    triggers {
        githubPush()
    }

    environment {
        DEPLOY_HOST = '208.87.132.201'
        DEPLOY_USER = 'mirza'
        APP_DIR = '/home/mirza/projects/docker/technical-test-simple-server'
        APP_BRANCH = 'main'
    }

    stages {
        stage('Unit Test') {
            steps {
                sh 'make test'
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Check Version'){
            steps {
                script {
                    def version = sh(
                        script: "make -s --eval='print-version:; @echo \$(VERSION)' print-version",
                        returnStdout: true
                    ).trim()

                    env.VERSION = version

                    echo "Release version: ${env.VERSION}"
                }
            }
        }


        stage('Build And Push') {
            steps {
                sh 'make build'

                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub-pat',
                        usernameVariable: 'DOCKERUSERNAME',
                        passwordVariable: 'DOCKERPAT'
                    )
                ]) {
                    sh '''
                        set +x
                        echo "$DOCKERPAT" | docker login \
                            --username "$DOCKERUSERNAME" \
                            --password-stdin
                    '''

                    sh 'make push'
                }
            }
        }

        stage('Deploy And Integration Test') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh \
                            -o StrictHostKeyChecking=accept-new \
                            "$DEPLOY_USER@$DEPLOY_HOST" \
                            "cd '$APP_DIR' &&

                             git fetch origin '$APP_BRANCH' && git checkout '$APP_BRANCH' &&
                             git reset --hard 'origin/$APP_BRANCH' &&

                             make release && make update &&

                             (make health || {
                                 echo 'Health check failed'
                                 make rollback
                                 exit 1
                             }) && echo 'Deployment completed successfully'"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Deployment completed successfully!'
        }

        failure {
            echo 'Deployment failed. Check the console log.'
        }

        always {
            echo "Pipeline finished with status: ${currentBuild.currentResult}"
        }
    }
}