 
 # we add INSTALL_RKE2_TYPE=agent
 curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -

 # create config file
 mkdir -p /etc/rancher/rke2/

 # change the ip to reflect your rancher1 ip
 echo "server: https://$RANCHER1_IP:9345" > /etc/rancher/rke2/config.yaml

 # change the Token to the one from rancher1 /var/lib/rancher/rke2/server/node-token
 echo "token: $TOKEN" >> /etc/rancher/rke2/config.yaml

 # enable and start
 systemctl enable rke2-agent.service
 systemctl start rke2-agent.service