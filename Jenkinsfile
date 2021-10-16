@Library('dst-shared@master') _

pipeline {
    agent {
        node { label 'metal-gcp-builder' }
    }

    options {
        timeout(time: 240, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '5'))
        timestamps()
    }

    environment {
        RELEASE_NAME = "csm"
        RELEASE_VERSION = sh(returnStdout: true, script: "./version.sh").trim()
        GIT_TAG = sh(returnStdout: true, script: "git rev-parse --short HEAD").trim()
        BRANCH_BUILD = branchBuild()
        SNYK_TOKEN = credentials('snyk-token')
    }

    stages {
        stage('Prepare Env') {
            steps {
                script {
                    sh "rm -fr dist"
                    sh """
                        rm -fr env3
                        python3 -m venv env3
                        . env3/bin/activate
                        python3 -m ensurepip --upgrade
                        pip install -U pyyaml
                    """
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    sh """
                        . env3/bin/activate
                        ./release.sh
                    """
                }
            }
        }

    }
}
