pipeline {
    agent { label "metal-gcp-builder" }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }

    stages {
        stage('Validate Docker Manifests'){
            steps {
                echo "Running validation"
                sh "./validate_docker_manifests.sh"
            }
        }
    }
}
