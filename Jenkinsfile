pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        DEPLOY_HOST = '208.87.132.201'
        DEPLOY_USER = 'mirza'
        APP_DIR = '/home/mirza/projects/docker/technical-test-simple-server'
        APP_BRANCH = 'main'
    }

    stages {
        stage('Update') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh -o StrictHostKeyChecking=yes \
                            "$DEPLOY_USER@$DEPLOY_HOST" \
                            "cd '$APP_DIR' &&
                             git fetch origin '$APP_BRANCH' &&
                             git pull --ff-only origin '$APP_BRANCH' &&
                             echo 'Source update completed'"
                    '''
                }
            }
        }

        stage('Build') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh -o StrictHostKeyChecking=yes \
                            "$DEPLOY_USER@$DEPLOY_HOST" \
                            "cd '$APP_DIR' &&
                             make build &&
                             echo 'Build completed'"
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh -o StrictHostKeyChecking=yes \
                            "$DEPLOY_USER@$DEPLOY_HOST" \
                            "cd '$APP_DIR' &&
                             make run &&
                             echo 'Deployment completed'"
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
    }
}