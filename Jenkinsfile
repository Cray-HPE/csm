@Library('dst-shared@master') _

pipeline {
    agent {
        node { label 'dstbuild' }
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
        stage('Build') {
            steps {
                script {
                    sh "rm -fr dist/ && ./release.sh"
                }
            }
        }

        stage('Publish ') {
            steps {
                script {
                    copyFiles("check_sem_version.sh")
                    sh "chmod +x check_sem_version.sh"
                    def version_check = sh(returnStdout: true, script: "./check_sem_version.sh ${env.RELEASE_VERSION}").trim()
                    if ("${version_check}" == "STABLE") {
                        def unstable = "false"
                    } else {
                        def unstable = "true"
                    }

                    if ( checkFileExists(filePath: "dist/*.tar.gz") ) {
                        transferDistToArti(artifactName:"dist/*.tar.gz",
                                           unstable: "${unstable}",
                                           product: 'csm',
                                           arch: 'shasta')
                    }
                }
            }
        }
    }
}
