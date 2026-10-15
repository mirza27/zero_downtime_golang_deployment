
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
        // stage('Unit Test') {
        //     steps {
        //         sh 'make test'
        //     }
        // }

        stage('Build And Push') {
            steps {

                // upload to docker repository
                // use docker agent to build and push image to docker repository

                sh 'make build VERSION=$VERSION'
            }
        }

        stage('Deploy') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh "$DEPLOY_USER@$DEPLOY_HOST" \
                            "cd '$APP_DIR' &&
                             make run &&
                             echo 'Container run completed'"
                    '''
                }
            }
        }

        stage('Integration Test') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh "$DEPLOY_USER@$DEPLOY_HOST" \
                            "cd '$APP_DIR' &&
                             make deploy &&
                             (make health || {
                                 echo 'Health check failed'
                                 make rollback
                                 exit 1
                             }) &&
                             echo 'Deployment completed successfully'"
                    '''
                }
            }
        }
    }
}