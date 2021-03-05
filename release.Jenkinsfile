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

    // TODO change SLACK_CHANNEL to 'casm_release_management'
    //SLACK_CHANNEL = 'casm_release_management'
    SLACK_CHANNEL = 'csm-release-alerts'
    // More fine grained details go here
    SLACK_DETAIL_CHANNEL = 'csm-release-alerts'

    ARTIFACTORY_PREFIX = 'https://arti.dev.cray.com/artifactory'

    // Branch to commits assets and git vendor changes to before tagging
    // TODO: change to master
    CSM_BRANCH = 'feature/CASMINST-1231-pipeline-of-pipelines-tmp'

    // TODO: need a
    STASH_SSH_CREDS = 'taylor-stash-ssh-key'
  }

  parameters {
    // Tag
    string(name: 'RELEASE_TAG', description: 'The release version without the "v" for this release. Eg "0.8.12"')
    string(name: 'RELEASE_JIRA', description: 'The release JIRA ticket. Eg CASMREL-576')
    // TODO change default to "release/0.8"
    string(name: 'CSM_RELEASE_BRANCH', description: 'The CSM release branch to create the CSM tag from', defaultValue: "feature/CASMINST-1231-pipeline-of-pipelines-release")

    // NCN Build parameters
    string(name: 'NCN_COMMON_TAG', description: "The NCN Common tag to use. If rebuilding we'll tag master as this first. If not rebuliding we'll verify this tag exists first")
    string(name: 'NCN_KUBERNETES_TAG', description: "The NCN Kubernetes tag to use. If rebuilding we'll tag master as this first. If not rebuliding we'll verify this tag exists first")
    string(name: 'NCN_CEPH_TAG', description: "The NCN Ceph tag to use. If rebuilding we'll tag master as this first. If not rebuliding we'll verify this tag exists first")

    booleanParam(name: 'BUILD_NCN_COMMON', defaultValue: true, description: "Does the release require a full build of node-image-non-compute-common? If unchecked we'll use the last stable version")
    booleanParam(name: 'BUILD_NCN_KUBERNETES', defaultValue: true, description: "Does the release require a full build of node-image-kubernetes?? If unchecked we'll use the last stable version. If common is rebuilt we will always rebuild kubernetes")
    booleanParam(name: 'BUILD_NCN_CEPH', defaultValue: true, description: "Does the release require a full build of node-image-storage-ceph? If unchecked we'll use the last stable version. If common is rebuilt we will always rebuild storage-ceph")
    booleanParam(name: 'NCNS_NEED_SMOKE_TEST', defaultValue: true, description: "Do we want to wait after NCNs are built for a smoke test to be done before building CSM")

    // LIVECD Build Parameters
    booleanParam(name: 'BUILD_LIVECD', defaultValue: true, description: "Does the release require a full build of cray-pre-install-toolkit (PIT/LiveCD)? If unchecked we'll grab the last version built form the release/shasta-1.4 branch")
  }

  stages {
    stage('Check Variables') {
      steps {
        script {
          env.RELEASE_IS_STABLE = checkSemVersion(params.RELEASE_TAG, "Invalid RELEASE_TAG")
          env.CSM_RELEASE_ARTIFACTORY_URL = "${ARTIFACTORY_PREFIX}/shasta-distribution-${env.RELEASE_IS_STABLE == 'true' ? 'stable' : 'unstable'}-local/csm/csm-${params.RELEASE_TAG}.tar.gz"

          env.NCN_COMMON_IS_STABLE = checkSemVersion(params.NCN_COMMON_TAG, "Invalid NCN_COMMON_TAG")
          env.NCN_COMMON_ARTIFACTORY_PREFIX = "${env.ARTIFACTORY_PREFIX}/node-images-${env.NCN_COMMON_IS_STABLE == 'true' ? 'stable' : 'unstable'}-local/shasta/non-compute-common/${params.NCN_COMMON_TAG}"

          env.NCN_KUBERNETES_IS_STABLE = checkSemVersion(params.NCN_KUBERNETES_TAG, "Invalid NCN_KUBERNETES_TAG")
          env.NCN_KUBERNETES_ARTIFACTORY_REPO = "node-images-${env.NCN_KUBERNETES_IS_STABLE == 'true' ? 'stable' : 'unstable'}-local/shasta/kubernetes/${params.NCN_KUBERNETES_TAG}"
          env.NCN_KUBERNETES_ARTIFACTORY_PREFIX = "${env.ARTIFACTORY_PREFIX}/${env.NCN_KUBERNETES_ARTIFACTORY_REPO}"

          env.NCN_CEPH_IS_STABLE = checkSemVersion(params.NCN_CEPH_TAG, "Invalid NCN_CEPH_TAG")
          env.NCN_CEPH_ARTIFACTORY_REPO = "node-images-${env.NCN_CEPH_IS_STABLE == 'true' ? 'stable' : 'unstable'}-local/shasta/storage-ceph/${params.NCN_CEPH_TAG}"
          env.NCN_CEPH_ARTIFACTORY_PREFIX = "${env.ARTIFACTORY_PREFIX}/${env.NCN_CEPH_ARTIFACTORY_REPO}"

          sh 'printenv | sort'

          jiraComment(issueKey: params.RELEASE_JIRA, body: "Jenkins started CSM Release ${params.RELEASE_TAG} build (${env.BUILD_NUMBER}) at ${env.BUILD_URL}.")
          slackSend(channel: env.SLACK_CHANNEL, color: "good", message: "CSM ${params.RELEASE_JIRA} ${params.RELEASE_TAG} Release Build Started\n${env.BUILD_URL}\n\nFollow additition details on #${env.SLACK_DETAIL_CHANNEL}")
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
                  // Wait for scan to complete
                  sleep 60
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
                      slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "Starting build ncn-kubernetes/master")
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
                      // Wait for scan to complete
                      sleep 60
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
            stage('Verify NCN k8s Artifacts') {
              steps {
                script {
                  def kernelFile = sh(returnStdout: true, script: "curl ${env.ARTIFACTORY_PREFIX}/api/storage/${env.NCN_KUBERNETES_ARTIFACTORY_REPO}/ | jq -r '.children[] | select(.uri|contains(\".kernel\")) | .uri '").trim()
                  echo "Got k8s kernel file of ${kernelFile}"

                  env.NCN_KUBERNETES_ARTIFACTORY_SQUASHFS = "${env.NCN_KUBERNETES_ARTIFACTORY_PREFIX}/kubernetes-${params.NCN_KUBERNETES_TAG}.squashfs"
                  env.NCN_KUBERNETES_ARTIFACTORY_KERNEL = "${env.NCN_KUBERNETES_ARTIFACTORY_PREFIX}${kernelFile}"
                  env.NCN_KUBERNETES_ARTIFACTORY_INITRD = "${env.NCN_KUBERNETES_ARTIFACTORY_PREFIX}/initrd.img-${params.NCN_KUBERNETES_TAG}.xz"

                  checkArtifactoryUrl(env.NCN_KUBERNETES_ARTIFACTORY_SQUASHFS)
                  checkArtifactoryUrl(env.NCN_KUBERNETES_ARTIFACTORY_KERNEL)
                  checkArtifactoryUrl(env.NCN_KUBERNETES_ARTIFACTORY_INITRD)
                }
              }
            }
          }
        } // END: NCN k8s

        stage('NCN Ceph') {
          stages {
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
                      slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "Starting build ncn-kubernetes/master")
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
                      // Wait for scan to complete
                      sleep 60
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
            stage('Verify NCN ceph Artifacts') {
              steps {
                script {
                  def kernelFile = sh(returnStdout: true, script: "curl ${env.ARTIFACTORY_PREFIX}/api/storage/${env.NCN_CEPH_ARTIFACTORY_REPO}/ | jq -r '.children[] | select(.uri|contains(\".kernel\")) | .uri '").trim()
                  echo "Got ceph kernel file of ${kernelFile}"

                  env.NCN_CEPH_ARTIFACTORY_SQUASHFS = "${env.NCN_CEPH_ARTIFACTORY_PREFIX}/storage-ceph-${params.NCN_CEPH_TAG}.squashfs"
                  env.NCN_CEPH_ARTIFACTORY_KERNEL = "${env.NCN_CEPH_ARTIFACTORY_PREFIX}${kernelFile}"
                  env.NCN_CEPH_ARTIFACTORY_INITRD = "${env.NCN_CEPH_ARTIFACTORY_PREFIX}/initrd.img-${params.NCN_CEPH_TAG}.xz"

                  checkArtifactoryUrl(env.NCN_CEPH_ARTIFACTORY_SQUASHFS)
                  checkArtifactoryUrl(env.NCN_CEPH_ARTIFACTORY_KERNEL)
                  checkArtifactoryUrl(env.NCN_CEPH_ARTIFACTORY_INITRD)
                }
              }
            }
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
                  echo "Triggering LiveCD Build casmpet-team/csm-release/livecd/release/shasta-1.4"
                  slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "Starting build casmpet-team/csm-release/livecd/release/shasta-1.4")
                  def result = build job: "casmpet-team/csm-release/livecd/release%2Fshasta-1.4", wait: true, propagate: true
                  echo "LiveCD Build Number ${result.number}"
                  env.LIVECD_LAST_BUILD_NUMBER = "${result.number}"
                }
              }
            } // END: Trigger LiveCD Build
            stage("Get Last LiveCD Build") {
              when {
                expression { return !params.BUILD_LIVECD}
              }
              steps {
                script {
                  echo "Getting last LiveCD Build from casmpet-team/csm-release/livecd/release/shasta-1.4"
                  def lastBuildNumber = getLastSuccessfulJenkinsBuildNumber("casmpet-team/csm-release/livecd/release%2Fshasta-1.4")
                  echo "Last Successful Build Number ${lastBuildNumber}"
                  env.LIVECD_LAST_BUILD_NUMBER = "${lastBuildNumber}"
                }
              }
            } // END: Get Last LiveCD Build
            stage("Get Last LiveCD Build Artifact Url") {
              steps {
                script {
                  // def liveCDLog = Jenkins.getInstance().getItemByFullName("casmpet-team/csm-release/livecd/release%2Fshasta-1.4").getBuildByNumber(result.getNumber()).log
                  // def liveCDLog = result.getRawBuild().getLog()
                  def searchRegex = /http:\/\/car.dev.cray.com\/artifactory\/csm\/MTL\/sle15_sp2_ncn\/x86_64\/release\/shasta-1.4\/casmpet-team\/cray-pre-install-toolkit-sle15sp2.x86_64-\d+\.\d+\.\d+-\d+-[a-z0-9]+/
                  def outputUrls = getJenkinsBuildOutput("casmpet-team/csm-release/livecd/release%2Fshasta-1.4", env.LIVECD_LAST_BUILD_NUMBER, searchRegex)

                  if(outputUrls.isEmpty()) {
                    error "Couldn't find LiveCD release url"
                  }

                  env.LIVECD_ARTIFACTORY_PREFIX = outputUrls[0]
                  env.LIVECD_ARTIFACTORY_ISO = "${env.LIVECD_ARTIFACTORY_PREFIX}.iso"
                  env.LIVECD_ARTIFACTORY_PACKAGES = "${env.LIVECD_ARTIFACTORY_PREFIX}.packages"
                  env.LIVECD_ARTIFACTORY_VERIFIED = "${env.LIVECD_ARTIFACTORY_PREFIX}.verified"
                  echo "Found LiveCD Release URL of ${env.LIVECD_ARTIFACTORY_PREFIX}"

                  echo "Checking LiveCD Artifacts Exists"
                  checkArtifactoryUrl(env.LIVECD_ARTIFACTORY_ISO)
                  checkArtifactoryUrl(env.LIVECD_ARTIFACTORY_PACKAGES)
                  checkArtifactoryUrl(env.LIVECD_ARTIFACTORY_VERIFIED)
                }
              }
            } // END: Get Last LiveCD Build Artifact Url
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
        slackSend(channel: env.SLACK_CHANNEL, message: "Waiting for Smoke Tests of CSM Release ${params.RELEASE_TAG}. Continue <${env.BUILD_URL}|job> to continue CSM Build!!")
        input message:"Was NCN Smoke Test Successful?"
      }
    }
    stage('CSM Build') {
      stages {
        stage('Prepare CSM git repo') {
          steps {
            script {
              slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "Starting CSM Git Vendor and Tags for ${params.RELEASE_TAG}.")

              sh """
                git status
                echo "Deleting branch ${CSM_BRANCH} locally to force sync with origin"
                git branch -d ${CSM_BRANCH} || true
                git checkout ${CSM_BRANCH}
                git pull
                git status
                git config user.email "jenkins@hpe.com"
                git config user.name "Jenkins CSM Release Job"
              """
            }
          }
        }
        stage('Update CSM assets') {
          steps {
            script {
              def pitAssets = "PIT_ASSETS=(\\n    ${env.LIVECD_ARTIFACTORY_ISO}\\n    ${env.LIVECD_ARTIFACTORY_PACKAGES}\\n    ${env.LIVECD_ARTIFACTORY_VERIFIED}\\n)".replaceAll("/","\\\\/")
              def k8sAssets = "KUBERNETES_ASSETS=(\\n    ${env.NCN_KUBERNETES_ARTIFACTORY_SQUASHFS}\\n    ${env.NCN_KUBERNETES_ARTIFACTORY_KERNEL}\\n    ${env.NCN_KUBERNETES_ARTIFACTORY_INITRD}\\n)".replaceAll("/","\\\\/")
              def cephAssets = "STORAGE_CEPH_ASSETS=(\\n    ${env.NCN_CEPH_ARTIFACTORY_SQUASHFS}\\n    ${env.NCN_CEPH_ARTIFACTORY_KERNEL}\\n    ${env.NCN_CEPH_ARTIFACTORY_INITRD}\\n)".replaceAll("/","\\\\/")
              sh """
                cp assets.sh assets.patched.sh
                sed -i -z "s/PIT_ASSETS=([^)]*)/${pitAssets}/" assets.patched.sh
                sed -i -z "s/KUBERNETES_ASSETS=([^)]*)/${k8sAssets}/" assets.patched.sh
                sed -i -z "s/STORAGE_CEPH_ASSETS=([^)]*)/${cephAssets}/" assets.patched.sh

                echo "new assets.sh"
                cat assets.patched.sh
                diff assets.sh assets.patched.sh || true

                if ! cmp assets.sh assets.patched.sh >/dev/null 2>&1
                then
                  echo "assets.sh differ. Committing change"
                  mv assets.patched.sh assets.sh
                  git status
                  git add assets.sh
                  git commit -m "Updating assets.sh for ${params.RELEASE_TAG} ${params.RELEASE_JIRA}"
                fi
              """

              echo "Validating assets.sh"
              sh "./assets.sh"
            }
          }
        }
        stage('Update CSM Git Vendor') {
          environment {
            PATH = "$WORKSPACE/git-vendor:$PATH"
          }
          steps {
            script {
              echo "Installing git vendor to path"
              sh """
                mkdir git-vendor
                curl https://raw.githubusercontent.com/brettlangdon/git-vendor/master/bin/git-vendor -o git-vendor/git-vendor
                chmod +x git-vendor/git-vendor
                git vendor list
              """

              echo "Updating git vendor branches"
              sh """
                git vendor update release master
                git vendor update shasta-cfg master
                git vendor update docs-csm-install release/shasta-1.4
                git --no-pager log ${CSM_BRANCH}..origin/${CSM_BRANCH}
              """
            }
          }
        }
        stage('Push CSM Git Commits') {
          steps {
            script {
              echo "Pushing commits to stash ${env.CSM_BRANCH} and merging to ${params.CSM_RELEASE_BRANCH}"
              sshagent([env.STASH_SSH_CREDS]) {
                sh """
                   git push -u origin ${env.CSM_BRANCH}
                   echo "Deleting branch ${params.CSM_RELEASE_BRANCH} locally to force sync with origin"
                   git branch -d ${params.CSM_RELEASE_BRANCH} || true
                   git checkout ${params.CSM_RELEASE_BRANCH}
                   git pull
                   git status
                   git merge --no-edit --no-ff origin/${env.CSM_BRANCH}
                   git push -u origin ${params.CSM_RELEASE_BRANCH}
                """
              }

            }
          }
        }
        stage('TAG CSM') {
          steps {
            script {
              echo
              echo "Tagging csm release ${params.RELEASE_TAG} from ${params.CSM_RELEASE_BRANCH}"
              sshagent([env.STASH_SSH_CREDS]) {
                sh """
                   git tag v${params.RELEASE_TAG}
                   git push origin v${params.RELEASE_TAG}
                """
              }
              echo "Scanning csm tags"
              build job: "casmpet-team/csm-release/csm", wait: false, propagate: false
              // Wait for scan to complete
              sleep 60
            }
          }
        }
        stage('Trigger CSM Build') {
          steps {
            script {
              slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "Starting build casmpet-team/csm-release/csm/v${params.RELEASE_TAG} for ${params.RELEASE_TAG}")
              build job: "casmpet-team/csm-release/csm/v${params.RELEASE_TAG}", wait: true, propagate: true
              slackSend(channel: env.SLACK_CHANNEL, color: "good", message: "Release ${params.RELEASE_TAG} ${params.RELEASE_JIRA} distribution at ${env.CSM_RELEASE_URL}")
            }
          }
        }
        stage('Upload release to GCP') {
          steps {
            script {
              withCredentials([file(credentialsId: 'csm-gcp-release-gcs-admin', variable: 'GCP_SA_FILE')]) {
                withEnv(["RELEASE_URL=${CSM_RELEASE_URL}", "GCP_FILE_NAME=csm-${params.RELEASE_TAG}.tar.gz", "DURATION=2d"]) {
                  sh'''
                    echo "" > signed_release_url.txt
                    docker run -e ARTIFACTORY_PROJECT -v $GCP_SA_FILE:/key.json google/cloud-sdk:latest -v ${WORKSPACE}/signed_release_url.txt:/url.txt /bin/bash -c '
                      set -e
                      apt update
                      apt install -y jq
                      gcloud auth activate-service-account --key-file /key.json

                      export CLOUDSDK_CORE_PROJECT=csm-release
                      gsutil ls


                      gcp_location="gs://csm-release/$ARTIFACTORY_PROJECT/${GCP_FILE_NAME}"
                      echo "Uploading ${RELEASE_URL} to ${gcp_location}

                      curl -L ${RELEASE_URL} | gsutil cp - $gcp_location

                      echo "Generate a presigned url"
                      response=$(gsutil signurl -d ${DURATION} /key.json ${gcp_location})
                      echo $response | tail -n 1 | awk '{print $5}' > /url.txt
                    '
                  '''
                  env.GCP_URL = sh(returnStdout: true, script: "cat ${WORKSPACE}/signed_release_url.txt").trim()
                  slackSend(channel: env.SLACK_CHANNEL, color: "good", message: "GCP Pre-Signed Release ${params.RELEASE_TAG} Distrubtion <${env.GCP_URL}|link>")
                  sh 'printenv | sort'
                }
              }
            }
          }
        }
      }
    } //END: Stage CSM Build
  } // END: Stages
  post('Post Run Conditions') {
    failure {
      script {
        slackSend(channel: env.SLACK_CHANNEL, color: "danger", message: "Jenkins Release ${params.RELEASE_TAG} Job Failed!! See <${env.BUILD_URL}|job> for details")
      }
    }
  }
}
