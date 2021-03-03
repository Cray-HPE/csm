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
    // Just start and finish alerts go to the main channel
    //SLACK_CHANNEL = 'casm_release_management'
    SLACK_CHANNEL = 'csm-release-alerts'
    // More fine grained details go here
    SLACK_DETAIL_CHANNEL = 'csm-release-alerts'
    ARTIFACTORY_PREFIX = 'https://arti.dev.cray.com/artifactory'
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

          env.NCN_COMMON_IS_STABLE = checkSemVersion(params.NCN_COMMON_TAG, "Invalid NCN_COMMON_TAG")
          env.NCN_COMMON_ARTIFACTORY_PREFIX = "${env.ARTIFACTORY_PREFIX}/node-images-${env.NCN_COMMON_IS_STABLE == 'true' ? 'stable' : 'unstable'}-local/shasta/non-compute-common/${params.NCN_COMMON_TAG}"

          env.NCN_KUBERNETES_IS_STABLE = checkSemVersion(params.NCN_KUBERNETES_TAG, "Invalid NCN_KUBERNETES_TAG")
          env.NCN_KUBERNETES_ARTIFACTORY_PREFIX = "${env.ARTIFACTORY_PREFIX}/node-images-${env.NCN_KUBERNETES_IS_STABLE == 'true' ? 'stable' : 'unstable'}-local/shasta/kubernetes/${params.NCN_KUBERNETES_TAG}"

          env.NCN_CEPH_IS_STABLE = checkSemVersion(params.NCN_CEPH_TAG, "Invalid NCN_CEPH_TAG")
          env.NCN_CEPH_ARTIFACTORY_PREFIX = "${env.ARTIFACTORY_PREFIX}/node-images-${env.NCN_CEPH_IS_STABLE == 'true' ? 'stable' : 'unstable'}-local/shasta/storage-ceph/${params.NCN_CEPH_TAG}"

          sh 'printenv | sort'

          jiraComment(issueKey: params.RELEASE_JIRA, body: "Jenkins started CSM Release build (${env.BUILD_NUMBER}) at ${env.BUILD_URL}.")
          slackSend(channel: env.SLACK_CHANNEL, color: "good", message: "CSM ${params.RELEASE_JIRA} ${params.RELEASE_TAG} Release Build Started\n${env.BUILD_URL}")
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
              checkArtifactoryUrl("${env.NCN_COMMON_ARTIFACTORY_PREFIX}/non-compute-common-${params.NCN_COMMON_TAG}.qcow2")
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
                  echo "Triggering non-compute-common build casmpet-team/csm-release/ncn-common/master"
                  slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "Starting build non-compute-common/master")
                  build job: "casmpet-team/csm-release/ncn-common/master",
                    parameters: [booleanParam(name: 'buildAndPublishMaster', value: true), booleanParam(name: 'allowDownstreamJobs', value: false)],
                    propagate: true
                }
              }
            }
            stage("Tag NCN Common") {
              steps {
                script {
                  echo "Tagging non-compute-common master as ${params.NCN_COMMON_TAG}"
                  tagRepo(project: "CLOUD", repo: "node-image-non-compute-common", tagName: params.NCN_COMMON_TAG, startPoint: "master")
                  echo "Scanning non-compute-common tags"
                  build job: "casmpet-team/csm-release/ncn-common", wait: false, propagate: false
                }
              }
            }
            stage("Trigger NCN Common TAG Promotion") {
              steps {
                script {
                  echo "Triggering TAG Promotion for casmpet-team/csm-release/ncn-common/${env.NCN_COMMON_TAG}"
                  build job: "casmpet-team/csm-release/ncn-common/${env.NCN_COMMON_TAG}",
                    parameters: [booleanParam(name: 'buildAndPublishMaster', value: false), booleanParam(name: 'allowDownstreamJobs', value: false)],
                    propagate: true
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
                  checkArtifactoryUrl("${env.NCN_KUBERNETES_ARTIFACTORY_PREFIX}/kubernetes-${params.NCN_KUBERNETES_TAG}.squashfs")
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
                      echo "Triggering kubernetes build casmpet-team/csm-release/ncn-kubernetes/master"
                      build job: "casmpet-team/csm-release/ncn-kubernetes/master",
                        parameters: [string(name: 'sourceArtifactsId', value: env.NCN_COMMON_TAG), booleanParam(name: 'buildAndPublishMaster', value: true)],
                        propagate: true
                    }
                  }
                }
                stage("Tag NCN k8s") {
                  steps {
                    script {
                      echo "Tagging node-image-kubernetes master as ${params.NCN_KUBERNETES_TAG}"
                      tagRepo(project: "CLOUD", repo: "node-image-kubernetes", tagName: params.NCN_KUBERNETES_TAG, startPoint: "master")
                      echo "Scanning ncn-kubernetes tags"
                      build job: "casmpet-team/csm-release/ncn-kubernetes", wait: false, propagate: false
                    }
                  }
                }
                stage("Trigger NCN k8s TAG Promotion") {
                  steps {
                    script {
                      echo "Triggering TAG Promotion for casmpet-team/csm-release/ncn-kubernetes/${env.NCN_KUBERNETES_TAG}"
                      build job: "casmpet-team/csm-release/ncn-kubernetes/${env.NCN_KUBERNETES_TAG}",
                        parameters: [booleanParam(name: 'buildAndPublishMaster', value: false)],
                        propagate: true
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
                  checkArtifactoryUrl("${env.NCN_CEPH_ARTIFACTORY_PREFIX}/storage-ceph-${params.NCN_CEPH_TAG}.squashfs")
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
                      echo "Triggering storage-ceph build casmpet-team/csm-release/ncn-storage-ceph/master"
                      build job: "casmpet-team/csm-release/ncn-storage-ceph/master",
                        parameters: [string(name: 'sourceArtifactsId', value: env.NCN_COMMON_TAG), booleanParam(name: 'buildAndPublishMaster', value: true)],
                        propagate: true
                    }
                  }
                }
                stage("Tag NCN Ceph") {
                  steps {
                    script {
                      echo "Tagging node-image-storage-ceph master as ${params.NCN_CEPH_TAG}"
                      tagRepo(project: "CLOUD", repo: "node-image-storage-ceph", tagName: params.NCN_CEPH_TAG, startPoint: "master")
                      echo "Scanning ncn-storage-ceph tags"
                      build job: "casmpet-team/csm-release/ncn-storage-ceph", wait: false, propagate: false
                    }
                  }
                }
                stage("Trigger NCN Ceph TAG Promotion") {
                  steps {
                    script {
                      echo "Triggering TAG Promotion for casmpet-team/csm-release/ncn-storage-ceph/${env.NCN_CEPH_TAG}"
                      build job: "casmpet-team/csm-release/ncn-storage-ceph/${env.NCN_CEPH_TAG}",
                        parameters: [booleanParam(name: 'buildAndPublishMaster', value: false)],
                        propagate: true
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
                  echo "Triggering LiveCD Build casmpet-team/csm-release/livecd/release%2Fshasta-1.4"
                  build job: "casmpet-team/csm-release/livecd/release%2Fshasta-1.4",
                        propagate: true
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
