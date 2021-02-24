// The pipeline of pipelines for doing a full CSM release
@Library('csm-shared-library@feature/CASMINST-1369') _
// @Library('dst-shared@master') _

pipeline {
  agent {
    node { label 'dstbuild' }
  }

  // Configuration options applicable to the entire job
  options {
    // This can take quite a long time for all downstream projects to run
    timeout(time: 4, unit: 'HOURS')

    // Don't fill up the build server with unnecessary cruft
    buildDiscarder(logRotator(numToKeepStr: '20'))

    disableConcurrentBuilds()

    timestamps()
  }

  parameters {
    // Tag
    string(name: 'RELEASE_TAG', description: 'The release version without the "v" for this release. Eg "0.8.12"')
    string(name: 'RELEASE_JIRA', description: 'The release JIRA ticket. Eg CASMREL-576')

    // NCN Build parameters
    booleanParam(name: 'BUILD_NCN_COMMON', defaultValue: true, description: "Does the release require a full build of node-image-non-compute-common? If unchecked we'll use the last stable version")
    booleanParam(name: 'BUILD_NCN_KUBERNETES', defaultValue: true, description: "Does the release require a full build of node-image-kubernetes?? If unchecked we'll use the last stable version. If common is rebuilt we will always rebuild kubernetes")
    booleanParam(name: 'BUILD_NCN_CEPH', defaultValue: true, description: "Does the release require a full build of node-image-storage-ceph? If unchecked we'll use the last stable version. If common is rebuilt we will always rebuild storage-ceph")

    // LIVECD Build Parameters
    booleanParam(name: 'BUILD_LIVECD', defaultValue: true, description: "Does the release require a full build of cray-pre-install-toolkit (PIT/LiveCD)? If unchecked we'll use the last stable version")
  }

  stages {
    stage('Check Variables') {
      steps {
        script {
          echo "TODO - Validate the RELEASE_TAG is semver format"
          echo "TODO - Validate the RELEASE_JIRA exists and all linked tickets are done?"
        }
      }
    }

    stage('NCN Common') {
      stages {
        // Just get the last stable version rather than rebuild it
        stage('Get Last Stable NCN Common Version') {
          when {
            expression { return !params.BUILD_NCN_COMMON }
          }
          steps {
            script {
              echo "TODO Get Last Stable NCN Common Version"
            }
          }
        }

        // Rebuild NCN Common
        stage('Build NCN Common') {
          when {
            expression { return params.BUILD_NCN_COMMON }
          }
          stages {
            stage("Trigger Master") {
              steps {
                script {
                  echo "TODO Trigger Master"
                  // build job: "cloud-team/node-images/kubernetes/master",
                  //       parameters: [booleanParam(name: 'buildAndPublishMaster', value: true), booleanParam(name: 'allowDownstreamJobs', value: false)],
                  //       propagate: true
                }
              }
            }
            stage("Tag") {
              steps {
                script {
                  echo "TODO TAG"
                }
              }
            }
            stage("Trigger TAG Promotion") {
              steps {
                script {
                  echo "TODO Trigger TAG Promotion"
                  // build job: "cloud-team/node-images/kubernetes/${env.NCN_TAG}",
                  //       parameters: [booleanParam(name: 'buildAndPublishMaster', value: true), booleanParam(name: 'allowDownstreamJobs', value: false)],
                  //       propagate: true
                }
              }
            }
          }
        } // END: Build NCN Common
      }
    } // END: NCN Common

  }
}
