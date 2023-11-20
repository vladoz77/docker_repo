pipeline{
  agent{
    label "slave-node"
  }
  tools{
    jdk "java17"
    maven "Maven3"
  }
  stages{
    stage("Clean-workspace"){
        steps{
            // Clean before build
            cleanWs()
        }
    }
    stage("checkout from scm"){
        steps{
          git branch: 'main', url: 'https://github.com/vladoz77/cicd-test-project'
        }
    }
  }
}