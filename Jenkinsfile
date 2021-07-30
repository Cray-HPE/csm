@Library('csm-shared-library@feature/CASMINST-1369') _
// @Library('dst-shared@master') _

pipeline {
    agent {
        //node { label 'dstbuild' }
        node { label 'metal-gcp-builder' }
    }

    // Configuration options applicable to the entire job
    options {
        // This build should not take long, fail the build if it appears stuck
        timeout(time: 240, unit: 'MINUTES')

        // Don't fill up the build server with unnecessary cruft
        buildDiscarder(logRotator(numToKeepStr: '5'))

        timestamps()
    }

    environment {
        RELEASE_NAME = 'csm'
        GIT_TAG = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
    }

    stages {
        stage('Set Version') {
            steps {
                script {
                    setVersion()
                    env.UNSTABLE_RELEASE="true"
                    // env.RELEASE_VERSION="0.8.5-alpha"
                    env.ARTIFACTORY_REPO="shasta-distribution-unstable-local"
                }
            }
        }
        stage('Record Environment') {
            steps {
                sh '''
                   env
                '''
            }
        }
        stage('Build Release Candidate Distribution') {
            steps {
                script {
                    def env = [
                        "RELEASE_VERSION=${env.RELEASE_VERSION}"
                    ]
                    withEnv(env) {
                        sh '''
                            ./release.sh
                        '''
                    }
                }
            }
        }
        stage('Publish ') {
            steps {
                script {
                    sh """
                      ls -lh dist/*${env.RELEASE_VERSION}*.tar.gz
                    """

                    rtServer (
                        id: 'ARTI_DOCKER_REGISTRY',
                        url: "https://${ARTI_DOCKER_REGISTRY}/artifactory",
                        credentialsId: 'artifact-server',
                        deploymentThreads: 10
                    )

                    rtUpload (
                        serverId: 'ARTI_DOCKER_REGISTRY',
                        failNoOp: true,
                        spec: """{
                            "files": [
                                {
                                "pattern": "dist/*${env.RELEASE_VERSION}*.tar.gz",
                                "target": "${env.ARTIFACTORY_REPO}/${env.RELEASE_NAME}/"
                                }
                            ]
                        }""",
                    )

                    // transferDistToArti (artifactName:"dist/*${env.RELEASE_VERSION}*.tar.gz",
                    //     unstable: "${env.UNSTABLE_RELEASE}",
                    //     product: "${env.RELEASE_NAME}")
                }
            }
        }
    }
}
