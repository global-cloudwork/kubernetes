#!/bin/bash
#Everything Is Supressed

echo "Script Start - Removing any existing rke2 features"

echo rke2 kill all script sucseeded
sudo /usr/local/bin/rke2-killall.sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false

echo rke2 uninstall script sucseeded
sudo /usr/local/bin/rke2-uninstall.sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false

echo system agent uninstall script sucseeded
curl -sS https://raw.githubusercontent.com/rancher/system-agent/main/system-agent-uninstall.sh | sudo sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false

echo folder removal sucseeded
rm -rf /etc/ceph \
       /etc/cni \
       /etc/kubernetes \
       /etc/rancher \
       /opt/cni \
       /run/calico \
       /run/flannel \
       /run/secrets/kubernetes.io \
       /var/lib/calico \
       /var/lib/cni \
       /var/lib/etcd \
       /var/lib/kubelet \
       /var/lib/rancher \
       /var/lib/weave \
       /var/log/containers \
       /var/log/pods \
       /var/run/calico &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo "relevant folders have been removed"

echo iptables removal sucseeded
sudo iptables -t nat -X FLANNEL-POSTRTG &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
