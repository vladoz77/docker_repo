#Get container ip
NFS_IP=$(docker container inspect nfs_server | jq '.[].NetworkSettings.Networks.nfs_default.IPAddress')

#NFS Client
sudo apt install nfs-client -y
sudo mount -t nfs4 ${NFS_IP}:/ /data