pipeline {
  agent { label "metal-gcp-builder" }

  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    disableConcurrentBuilds()
    timestamps()
  }

  stages {
    stage('Setup Tools'){
      steps {
        sh "./validate.sh install_tools"
        sh "./validate.sh gen_helm_images"
      }
    }

    stage('Validate') {
      parallel {
        stage('Assets'){
          steps {
            sh "./assets.sh"
          }
        }
        stage('Helm'){
          steps {
            sh "./validate.sh validate_helm"
          }
        }

        stage('RPM Index'){
          steps {
            sh "./validate.sh validate_rpm_index"
          }
        }

        stage('Containers'){
          steps {
            sh "./validate.sh validate_containers"
          }
        }

        stage('Helm Versions'){
          steps {
            sh "./validate.sh validate_manifest_versions"
          }
        }

        stage('Helm Images'){
          steps {
            sh "./validate.sh update_helmrepo"
            sh "./validate.sh validate_helm_images"
          }
        }
      }
    }
  }
}
