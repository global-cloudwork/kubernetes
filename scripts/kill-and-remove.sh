#!/bin/bash
#Everything Is Supressed

echo "Script Start - Removing any existing rke2 features"

curl -sS https://raw.githubusercontent.com/rancher/system-agent/main/system-agent-uninstall.sh | sudo sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo "the system agent uninstall script ran"

sudo /usr/local/bin/rke2-killall.sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo "the kill all script ran"

sudo /usr/local/bin/rke2-uninstall.sh &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo "the rke2 uninstall script ran"

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

sudo iptables -t nat -X FLANNEL-POSTRTG &>/dev/null
[ $? -eq 0 ] && echo -n true || echo -n false
echo "the iptables have been removed"
