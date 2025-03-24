#Get container ip
NFS_IP=$(docker container inspect nfs_server | jq '.[].NetworkSettings.Networks[].IPAddress')

#NFS Client
sudo apt install nfs-client -y
sudo mount -v -o vers=4,loud 172.21.0.2:/ /data  