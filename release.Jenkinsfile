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

  environment {
    SLACK_CHANNEL = 'casm_release_management'
  }

  parameters {
    // Tag
    string(name: 'RELEASE_TAG', description: 'The release version without the "v" for this release. Eg "0.8.12"')
    string(name: 'RELEASE_JIRA', description: 'The release JIRA ticket. Eg CASMREL-576')

    // NCN Build parameters
    booleanParam(name: 'BUILD_NCN_COMMON', defaultValue: true, description: "Does the release require a full build of node-image-non-compute-common? If unchecked we'll use the last stable version")
    booleanParam(name: 'BUILD_NCN_KUBERNETES', defaultValue: true, description: "Does the release require a full build of node-image-kubernetes?? If unchecked we'll use the last stable version. If common is rebuilt we will always rebuild kubernetes")
    booleanParam(name: 'BUILD_NCN_CEPH', defaultValue: true, description: "Does the release require a full build of node-image-storage-ceph? If unchecked we'll use the last stable version. If common is rebuilt we will always rebuild storage-ceph")
    booleanParam(name: 'NCNS_NEED_SMOKE_TEST', defaultValue: true, description: "Do we want to wait after NCNs are built for a smoke test to be done before building CSM")

    string(name: 'NCN_COMMON_TAG', description: "The NCN Common tag to use. If rebuilding we'll tag master as this first. If not rebuliding we'll verify this tag exists first")
    string(name: 'NCN_KUBERNETES_TAG', description: "The NCN Kubernetes tag to use. If rebuilding we'll tag master as this first. If not rebuliding we'll verify this tag exists first")
    string(name: 'NCN_CEPH_TAG', description: "The NCN Ceph tag to use. If rebuilding we'll tag master as this first. If not rebuliding we'll verify this tag exists first")

    // LIVECD Build Parameters
    booleanParam(name: 'BUILD_LIVECD', defaultValue: true, description: "Does the release require a full build of cray-pre-install-toolkit (PIT/LiveCD)? If unchecked we'll use the last stable version")
  }

  stages {
    stage('Check Variables') {
      steps {
        script {
          checkSemVersion(params.RELEASE_TAG, "Invalid RELEASE_TAG")
          checkSemVersion(params.NCN_COMMON_TAG, "Invalid NCN_COMMON_TAG")
          checkSemVersion(params.NCN_KUBERNETES_TAG, "Invalid NCN_KUBERNETES_TAG")
          checkSemVersion(params.NCN_CEPH_TAG, "Invalid NCN_CEPH_TAG")

          jiraComment(issueKey: params.RELEASE_JIRA, body: "Jenkins started CSM Release build (${env.BUILD_NUMBER}) at ${env.BUILD_URL}.")
          // Disabling while testing
          // slackSend(channel: env.SLACK_CHANNEL, color: "good", message: "CSM ${params.RELEASE_JIRA} ${params.RELEASE_TAG} Release Build Started\n${env.BUILD_URL}")
        }
      }
    } // END: Stage Check Variables

    // Build or Get NCN Common First
    stage('NCN Common') {
      stages {
        stage('Verify NCN Common TAG') {
          when {
            expression { return !params.BUILD_NCN_COMMON }
          }
          steps {
            script {
               echo "TODO verify tag exists in artifactory"
            }
          }
        }

        // Rebuild NCN Common
        stage('Build NCN Common') {
          when {
            expression { return params.BUILD_NCN_COMMON }
          }
          stages {
            stage("Trigger NCN Common Master") {
              steps {
                script {
                  echo "TODO Trigger Master"
                  // build job: "cloud-team/node-images/non-compute-common/master",
                  //       parameters: [booleanParam(name: 'buildAndPublishMaster', value: true), booleanParam(name: 'allowDownstreamJobs', value: false)],
                  //       propagate: true
                }
              }
            }
            stage("Tag NCN Common") {
              steps {
                script {
                  // TODO make sure we are tagging same sha that was built above
                  echo "TODO TAG"
                }
              }
            }
            stage("Trigger NCN Common TAG Promotion") {
              steps {
                script {
                  echo "TODO Trigger TAG Promotion"
                  // build job: "cloud-team/node-images/non-compute-common/${env.NCN_TAG}",
                  //       parameters: [booleanParam(name: 'buildAndPublishMaster', value: false), booleanParam(name: 'allowDownstreamJobs', value: false)],
                  //       propagate: true
                }
              }
            }
          }
        } // END: Build NCN Common
      }
    } // END: NCN Common

    stage('k8s, Ceph, and LiveCD') {
      // We'll run these 3 in parallel because we can't have nested parallel steps in declarative pipelines
      // so its not possible to run LiveCD at the same time as NCN Common
      parallel {
        stage('NCN k8s') {
          stages {
            stage('Verify NCN k8s TAG') {
              when {
                expression { return !params.BUILD_NCN_COMMON && !params.BUILD_NCN_KUBERNETES}
              }
              steps {
                script {
                  echo "TODO verify tag exists in artifactory"
                }
              }
            }
            // Rebuild k8s
            stage('BUILD NCN k8s') {
              when {
                expression { return params.BUILD_NCN_COMMON || params.BUILD_NCN_KUBERNETES}
              }
              stages {
                stage("Trigger NCN k8s Master") {
                  steps {
                    script {
                      echo "TODO Trigger Master"
                      // build job: "cloud-team/node-images/kubernetes/master",
                      //       parameters: [string(name: 'sourceArtifactsId', value: env.TODO), booleanParam(name: 'buildAndPublishMaster', value: true)],
                      //       propagate: true
                    }
                  }
                }
                stage("Tag NCN k8s") {
                  steps {
                    script {
                      // TODO make sure we are tagging same sha that was built above
                      echo "TODO TAG"
                    }
                  }
                }
                stage("Trigger NCN k8s TAG Promotion") {
                  steps {
                    script {
                      echo "TODO Trigger TAG Promotion"
                      // build job: "cloud-team/node-images/kubernetes/${env.NCN_TAG}",
                      //       parameters: [booleanParam(name: 'buildAndPublishMaster', value: false)],
                      //       propagate: true
                    }
                  }
                }
              }
            } // END: Build NCN k8s
          }
        } // END: NCN k8s

        stage('NCN Ceph') {
          stages {
            stage('Verify NCN ceph TAG') {
              when {
                expression { return !params.BUILD_NCN_COMMON && !params.BUILD_NCN_CEPH}
              }
              steps {
                script {
                   echo "TODO verify tag exists in artifactory"
                }
              }
            }
            // Rebuild Ceph
            stage('BUILD NCN Ceph') {
              when {
                expression { return params.BUILD_NCN_COMMON || params.BUILD_NCN_CEPH}
              }
              stages {
                stage("Trigger NCN Ceph Master") {
                  steps {
                    script {
                      echo "TODO Trigger Master"
                      // build job: "cloud-team/node-images/storage-ceph/master",
                      //       parameters: [string(name: 'sourceArtifactsId', value: env.TODO), booleanParam(name: 'buildAndPublishMaster', value: true)],
                      //       propagate: true
                    }
                  }
                }
                stage("Tag NCN Ceph") {
                  steps {
                    script {
                      // TODO make sure we are tagging same sha that was built above
                      echo "TODO TAG"
                    }
                  }
                }
                stage("Trigger NCN Ceph TAG Promotion") {
                  steps {
                    script {
                      echo "TODO Trigger TAG Promotion"
                      // build job: "cloud-team/node-images/storage-ceph/${env.NCN_TAG}",
                      //       parameters: [booleanParam(name: 'buildAndPublishMaster', value: false)],
                      //       propagate: true
                    }
                  }
                }
              }
            } // END: Build NCN Ceph
          }
        } // END: NCN Ceph

        stage("LiveCD") {
          stages {
            stage("Trigger LiveCD Build") {
              when {
                expression { return params.BUILD_LIVECD}
              }
              steps {
                script {
                  echo "TODO Trigger LiveCD Build"
                  // build job: "cloud-team/node-images/cray-pre-install-tookit/release/1.4",
                  //       parameters: [booleanParam(name: 'buildAndPublishMaster', value: false)],
                  //       propagate: true
                  echo "TODO need to find a way to get the artifactory release with <timestamp>-<sha>.iso from build"
                }
              }
            } // END: Trigger LiveCD Build
          }
        } // END: Stage LiveCD
      } // END: Parallel
    } // END: 'k8s, Ceph, and LiveCD

    stage('Wait for Smoke Test of NCNs'){
      // This is not automated yet so we'll just ask if it was done manually for now
      when {
        // Only need to wait if NCS were actually rebuilt
        expression { return params.NCNS_NEED_SMOKE_TEST && (params.BUILD_NCN_COMMON || params.BUILD_NCN_KUBERNETES || params.BUILD_NCN_CEPH)}
      }
      steps {
        input message:"Was NCN Smoke Test Successful?"
      }
    }
    stage('CSM Build') {
      stages {
        stage('Update CSM assets') {
          steps {
            script {
              echo "TODO: Make commit to assets.sh"
            }
          }
        }
        stage('Update CSM Git Vendor') {
          steps {
            script {
              echo "TODO: do git vendor and push"
            }
          }
        }
        stage('TAG CSM') {
          steps {
            script {
              echo "TODO: merge release branch and tag"
            }
          }
        }
        stage('Wait for CSM Build') {
          steps {
            script {
              // Might be worth it to make it so tags aren't built automatically on CSM so we can control it here
              echo "TODO: find a way to wait for the CSM build and wait for it"
            }
          }
        }
      }
    }
  } // END: Stages
}
