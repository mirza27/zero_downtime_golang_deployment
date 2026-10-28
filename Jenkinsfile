
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
        DEPLOY_HOST = credentials('deploy-host') // Jenkins secret-text credential or fallback to env
        DEPLOY_USER = 'deploy'
        APP_DIR = '/opt/apps/technical-test-simple-server'
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
                    def imageTag = sh(
                        script: "make -s --eval='print-tag:; @echo \$(IMAGE_TAG)' print-tag",
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = imageTag

                    echo "Release version / Image Tag: ${env.IMAGE_TAG}"
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