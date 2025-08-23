#!/bin/bash
#Everything Is Supressed

echo "Removal Status"

curl -sS https://raw.githubusercontent.com/rancher/system-agent/main/system-agent-uninstall.sh | sudo sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo ": System Agent Removal"

sudo /usr/local/bin/rke2-killall.sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo ": RKE2 Kill All"

sudo /usr/local/bin/rke2-uninstall.sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo ": RKE2 Uninstall"

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
echo ": Remove Folders"

sudo iptables -t nat -X FLANNEL-POSTRTG &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo ": Remove IPTables"