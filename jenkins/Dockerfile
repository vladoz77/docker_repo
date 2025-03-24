FROM jenkins/jenkins:lts-jdk17

# Install Jenkins plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Disable the setup wizard as we will set up Jenkins as code
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

# Copy the Configuration as Code (CasC) YAML file into the image
COPY jenkins.yaml /var/jenkins_home/casc_configs/jenkins.yaml

# Tell the Jenkins Configuration as Code plugin where to find the YAML file
ENV CASC_JENKINS_CONFIG="/var/jenkins_home/casc_configs/jenkins.yaml"