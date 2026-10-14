pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        DEPLOY_HOST = '203.0.113.10'
        DEPLOY_USER = 'mirza'
        APP_DIR = '~/projects/docker/technical-test-simple-server'
        APP_BRANCH = 'main'
    }

    stages {
        stage('Update') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh "$DEPLOY_USER@$DEPLOY_HOST" \
                            "bash -se" <<'REMOTE'
                            set -eu

                            cd "$APP_DIR"

                            git fetch origin "$APP_BRANCH"
                            git pull --ff-only origin "$APP_BRANCH"

                        REMOTE
                    '''
                }
            }
        }


        stage('Build') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh "$DEPLOY_USER@$DEPLOY_HOST" \
                            "bash -se" <<'REMOTE'
                            set -eu

                            cd "$APP_DIR"

                            make build

                        REMOTE
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(credentials: ['deploy-ssh']) {
                    sh '''
                        set -eu

                        ssh "$DEPLOY_USER@$DEPLOY_HOST" \
                            "bash -se" <<'REMOTE'
                            set -eu

                            cd "$APP_DIR"

                            make run

                        REMOTE
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