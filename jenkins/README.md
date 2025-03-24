# Get password
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Get ssh
export SSH_PRIVATE_KEY=$(ssh jenkins@192.168.59.100 cat .ssh/id_rsa)