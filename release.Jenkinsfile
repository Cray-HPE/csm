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
    timeout(time: 8, unit: 'HOURS')

    // Don't fill up the build server with unnecessary cruft
    buildDiscarder(logRotator(numToKeepStr: '20'))

    disableConcurrentBuilds()

    timestamps()
  }

  environment {
    // Just start and finish alerts go to the main channel

    // More fine grained details go here
    SLACK_DETAIL_CHANNEL = 'csm-release-alerts'

    ARTIFACTORY_PREFIX = 'https://arti.dev.cray.com/artifactory'

    // TODO: need a
    STASH_SSH_CREDS = 'taylor-stash-ssh-key'
  }

  parameters {
    // Tag
    string(name: 'RELEASE_TAG', description: 'The release version without the "v" for this release. Eg "0.8.12"')
    string(name: 'RELEASE_JIRA', description: 'The release JIRA ticket. Eg CASMREL-576')

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

    // CSM Parameters
    booleanParam(name: 'CSM_FORCE_PUSH_TAG', defaultValue: false, description: "Should we force push the CSM Tag? This is useful if we want to retrigger a CSM build.")
    booleanParam(name: 'UPLOAD_RELEASE_TO_GCP', defaultValue: true, description: "If the release tarball should be uploaded to GCP after it's built")

    string(name: 'CSM_RELEASE_BRANCH', description: 'The CSM release branch to create the CSM tag from', defaultValue: "release/0.8")
    string(name: 'CSM_MAIN_BRANCH', description: 'The CSM release branch to update assets.sh and git vendor and to merge into the release branch', defaultValue: "main")
    string(name: 'SLACK_CHANNEL', description: 'The slack channel to send primary messages to', defaultValue: "casm_release_management")
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
          slackSend(channel: params.SLACK_CHANNEL, color: "good", message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Release Build Started For Jira ${params.RELEASE_JIRA}\nFollow additional details on #${env.SLACK_DETAIL_CHANNEL}")
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
                  slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Starting build non-compute-common/master")
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
                  retry(3){
                    tagRepo(project: "CLOUD", repo: "node-image-non-compute-common", tagName: params.NCN_COMMON_TAG, startPoint: "master")
                  }
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

    stage('Build Images') {
      // We'll run these 3 in parallel because we can't have nested parallel steps in declarative pipelines
      // so its not possible to run LiveCD at the same time as NCN Common
      parallel {
        stage('NCN k8s') {
          when {
            expression { return params.BUILD_NCN_COMMON || params.BUILD_NCN_KUBERNETES}
          }
          stages {
            stage("Trigger NCN k8s Master") {
              steps {
                script {
                  echo "Triggering kubernetes build casmpet-team/csm-release/ncn-kubernetes/master"
                  slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Starting build ncn-kubernetes/master")
                  def result = build job: "casmpet-team/csm-release/ncn-kubernetes/master",
                    parameters: [string(name: 'sourceArtifactsId', value: env.NCN_COMMON_TAG), booleanParam(name: 'buildAndPublishMaster', value: true)],
                    propagate: true

                  env.NCN_KUBERNETES_MASTER_BUILD_NUMBER = result.number

                }
              }
            }
            stage("Get Last k8s Build Number") {
              steps {
                script {
                  echo "Getting unstable release number for testing"
                  def searchRegex = /Deploying artifact: https:\/\/arti.dev.cray.com\/artifactory\/node-images-(unstable|stable)-local\/shasta\/kubernetes\/[a-z0-9]{7}-[0-9]{13}\//
                  def outputUrls = getJenkinsBuildOutput("casmpet-team/csm-release/ncn-kubernetes/master", env.NCN_KUBERNETES_MASTER_BUILD_NUMBER, searchRegex)

                  if(outputUrls.isEmpty()) {
                    error "Couldn't Find NCN Unstable Release URL"
                  }
                  env.NCN_KUBERNETES_UNSTABLE_RELEASE_NUMBER = outputUrls[0].reverse().substring(1,22).reverse()
                }
              }
            }
          }
        } // END: NCN k8s

        stage('NCN Ceph') {
          when {
            expression { return params.BUILD_NCN_COMMON || params.BUILD_NCN_CEPH}
          }
          stages {
            stage("Trigger NCN Ceph Master") {
              steps {
                script {
                  echo "Triggering storage-ceph build casmpet-team/csm-release/ncn-storage-ceph/master"
                  slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Starting build ncn-storage-ceph/master")
                  def result = build job: "casmpet-team/csm-release/ncn-storage-ceph/master",
                    parameters: [string(name: 'sourceArtifactsId', value: env.NCN_COMMON_TAG), booleanParam(name: 'buildAndPublishMaster', value: true)],
                    propagate: true

                  env.NCN_CEPH_MASTER_BUILD_NUMBER = result.number
                }
              }
            }
            stage("Get Last Ceph Build Number") {
              steps {
                script {
                  echo "Getting unstable release number for testing"
                  def searchRegex = /Deploying artifact: https:\/\/arti.dev.cray.com\/artifactory\/node-images-(unstable|stable)-local\/shasta\/storage-ceph\/[a-z0-9]{7}-[0-9]{13}\//
                  def outputUrls = getJenkinsBuildOutput("casmpet-team/csm-release/ncn-storage-ceph/master", env.NCN_CEPH_MASTER_BUILD_NUMBER, searchRegex)

                  if(outputUrls.isEmpty()) {
                    error "Couldn't Find NCN Unstable Release URL"
                  }
                  env.NCN_CEPH_UNSTABLE_RELEASE_NUMBER = outputUrls[0].reverse().substring(1,22).reverse()
                }
              }
            }
          }
        } // END: NCN Ceph
        stage("LiveCD") {
          stages {
            stage("Trigger Build") {
              when {
                expression { return params.BUILD_LIVECD}
              }
              steps {
                script {
                  echo "Triggering LiveCD Build casmpet-team/csm-release/livecd/release/shasta-1.4"
                  slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Starting build casmpet-team/csm-release/livecd/release/shasta-1.4")
                  def result = build job: "casmpet-team/csm-release/livecd/release%2Fshasta-1.4", wait: true, propagate: true
                  echo "LiveCD Build Number ${result.number}"
                  env.LIVECD_LAST_BUILD_NUMBER = "${result.number}"
                }
              }
            } // END: Trigger Build
            stage("Get Build Number") {
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
            } // END: Get Build Number
          }
        } // END: Stage LiveCD
      } // END: Parallel
    } // END: Build Images

    stage('Wait for Smoke Test of NCNs'){
      // This is not automated yet so we'll just ask if it was done manually for now
      when {
        // Only need to wait if NCS were actually rebuilt
        expression { return params.NCNS_NEED_SMOKE_TEST && (params.BUILD_NCN_COMMON || params.BUILD_NCN_KUBERNETES || params.BUILD_NCN_CEPH)}
      }
      steps {
        script {
          def message = """
            <${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Images Built. Begin Metal Smoke Tests!!!.
            Then Proceed the <${env.BUILD_URL}|job> to Continue the Build.
            K8S Release = `${params.BUILD_NCN_KUBERNETES || params.BUILD_NCN_COMMON ? env.NCN_KUBERNETES_UNSTABLE_RELEASE_NUMBER : env.NCN_KUBERNETES_TAG}`
            Ceph Release = `${params.BUILD_NCN_CEPH || params.BUILD_NCN_COMMON ? env.NCN_CEPH_UNSTABLE_RELEASE_NUMBER : env.NCN_CEPH_TAG}`
          """.stripIndent()
          slackSend(channel: params.SLACK_CHANNEL, message: message)
          input message:"Was NCN Smoke Test Successful?"
          slackSend(channel: params.SLACK_CHANNEL, message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Smoke Tests Finished. Continuing with build.")
        }
      }
    }

    stage('Promote NCN Images'){
      parallel {
        stage('NCN k8s') {
          when {
            expression { return params.BUILD_NCN_COMMON || params.BUILD_NCN_KUBERNETES}
          }
          stages{
            stage("Tag NCN k8s") {
              steps {
                script {
                  echo "Tagging node-image-kubernetes master as ${params.NCN_KUBERNETES_TAG}"
                  retry(3){
                    tagRepo(project: "CLOUD", repo: "node-image-kubernetes", tagName: params.NCN_KUBERNETES_TAG, startPoint: "master")
                  }
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
        } // END: NCN K8s
        stage('NCN Ceph') {
          when {
            expression { return params.BUILD_NCN_COMMON || params.BUILD_NCN_CEPH}
          }
          stages{
            stage("Tag NCN Ceph") {
              steps {
                script {
                  echo "Tagging node-image-storage-ceph master as ${params.NCN_CEPH_TAG}"
                  retry(3){
                    tagRepo(project: "CLOUD", repo: "node-image-storage-ceph", tagName: params.NCN_CEPH_TAG, startPoint: "master")
                  }
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
        } // END: Stage NCN Ceph
      } // END: Parallel Promote NCN Images
    } // END: Stage Promote NCN Images

    stage('Verify Images') {
      parallel {
        stage('K8s Artifacts') {
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
        stage('Ceph Artifacts') {
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
        stage("LiveCD Artifacts") {
          steps {
            script {
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
        } // END: LiveCD Artifacts
      }
    }
    stage('Prep CSM Build') {
      stages {
        stage('Prepare CSM git repo') {
          steps {
            script {
              slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Starting CSM Git Vendor and Tags")

              sh """
                git status
                echo "Deleting branch ${params.CSM_MAIN_BRANCH} locally to force sync with origin"
                git branch -D ${params.CSM_MAIN_BRANCH} || true
                git checkout ${params.CSM_MAIN_BRANCH}
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
                mkdir -p git-vendor
                curl https://raw.githubusercontent.com/brettlangdon/git-vendor/master/bin/git-vendor -o git-vendor/git-vendor
                chmod +x git-vendor/git-vendor
                git vendor list
              """

              echo "Updating git vendor branches"
              sh """
                git vendor update release master
                git vendor update shasta-cfg master
                git vendor update docs-csm-install release/shasta-1.4
                git --no-pager log ${params.CSM_MAIN_BRANCH}...origin/${params.CSM_MAIN_BRANCH}
              """
            }
          }
        }
        stage('Push CSM Git Commits') {
          steps {
            script {
              echo "Pushing commits to stash ${params.CSM_MAIN_BRANCH} and merging to ${params.CSM_RELEASE_BRANCH}"
              sshagent([env.STASH_SSH_CREDS]) {
                sh """
                   git push -u origin ${params.CSM_MAIN_BRANCH}
                   echo "Deleting branch ${params.CSM_RELEASE_BRANCH} locally to force sync with origin"
                   git branch -D ${params.CSM_RELEASE_BRANCH} || true
                   git checkout ${params.CSM_RELEASE_BRANCH}
                   git pull
                   git status
                   git merge --no-edit --no-ff origin/${params.CSM_MAIN_BRANCH}
                   git push -u origin ${params.CSM_RELEASE_BRANCH}
                """
              }

            }
          }
        }
        stage('TAG CSM') {
          steps {
            script {
              echo "Tagging csm release ${params.RELEASE_TAG} from ${params.CSM_RELEASE_BRANCH}"
              sshagent([env.STASH_SSH_CREDS]) {
                sh """
                   git tag ${params.CSM_FORCE_PUSH_TAG ? "--force" : ""} v${params.RELEASE_TAG}
                   git push ${params.CSM_FORCE_PUSH_TAG ? "--force" : ""} origin v${params.RELEASE_TAG}
                """
              }
              echo "Scanning csm tags"
              build job: "casmpet-team/csm-release/csm", wait: false, propagate: false
              // Wait for scan to complete
              sleep 60
            }
          }
        }

      }
    } //END: Prep CSM Build
    stage('Trigger CSM Build') {
      steps {
        script {
          slackSend(channel: env.SLACK_DETAIL_CHANNEL, message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Starting build casmpet-team/csm-release/csm/v${params.RELEASE_TAG}")
          retry(3) {
            build job: "casmpet-team/csm-release/csm/v${params.RELEASE_TAG}", wait: true, propagate: true
          }
          slackSend(channel: env.SLACK_CHANNEL, color: "good", message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Release distribution at ${env.CSM_RELEASE_ARTIFACTORY_URL}")
        }
      }
    }
    stage('Upload release to GCP') {
      when {
        expression { return params.UPLOAD_RELEASE_TO_GCP }
      }
      steps {
        script {
          withCredentials([file(credentialsId: 'csm-gcp-release-gcs-admin', variable: 'GCP_SA_FILE')]) {
            withEnv(["RELEASE_URL=${CSM_RELEASE_ARTIFACTORY_URL}", "GCP_FILE_NAME=csm-${params.RELEASE_TAG}.tar.gz", "DURATION=2d"]) {
              try {
                sh'''
                  echo "" > signed_release_url.txt
                  docker run -e RELEASE_URL -e GCP_FILE_NAME -e DURATION -v $GCP_SA_FILE:/key.json -v ${WORKSPACE}:/workspace google/cloud-sdk:329.0.0-alpine /bin/bash -c '
                    set -e
                    set -o pipefail
                    apk add jq
                    gcloud auth activate-service-account --key-file /key.json

                    export CLOUDSDK_CORE_PROJECT=csm-release
                    gsutil ls

                    GCP_LOCATION="gs://csm-release/csm/${GCP_FILE_NAME}"
                    echo "Uploading ${RELEASE_URL} to ${GCP_LOCATION}"
                    curl -I ${RELEASE_URL}

                    # Streaming Way
                    curl -L ${RELEASE_URL} | gsutil -D cp - $GCP_LOCATION

                    # Temp File Way
                    # curl ${RELEASE_URL} -o /workspace/${GCP_FILE_NAME}
                    # ls -lh /workspace/${GCP_FILE_NAME}
                    # gsutil cp -o GSUtil:parallel_composite_upload_threshold=150M /workspace/${GCP_FILE_NAME} $GCP_LOCATION
                    # rm -rf /workspace/${GCP_FILE_NAME}

                    echo "Generate a presigned url"
                    gsutil signurl -d ${DURATION} /key.json ${GCP_LOCATION} > /workspace/signed_release_url.txt
                    cat /workspace/signed_release_url.txt
                  '
                '''
                env.GCP_URL = sh(returnStdout: true, script: "cat ${WORKSPACE}/signed_release_url.txt | tail -n 1 | awk '{print \$5}'").trim()
                slackSend(channel: params.SLACK_CHANNEL, color: "good", message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - GCP Pre-Signed Release Distrubtion <${env.GCP_URL}|link>")
              } catch (Exception e) {
                slackSend(channel: params.SLACK_DETAIL_CHANNEL, color: "danger", message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Error uploading CSM tarball to GCS")
              }
            }
          }
        }
      }
    }
  } // END: Stages
  post('Post Run Conditions') {
    failure {
      script {
        slackSend(channel: params.SLACK_CHANNEL, color: "danger", message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Job Failed!! See console for details")
      }
    }
    aborted {
      script {
        slackSend(channel: params.SLACK_DETAIL_CHANNEL, color: "danger", message: "<${env.BUILD_URL}|CSM Release ${params.RELEASE_TAG}> - Job Aborted!! See console for details")
      }
    }
    always {
      script {
        sh 'printenv | sort'
      }
      cleanWs()
    }
  }
}
