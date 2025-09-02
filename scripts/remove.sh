#!/bin/bash
#Everything Is Supressed

echo() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

h1 "Removing Existing RKE2 Resources"

echo "remove symbolic links before re-installing"
rm $HOME/.kube/config
sudo rm /usr/local/bin/kubectl

echo "rke2 kill all script succeeded"
sudo /usr/local/bin/rke2-killall.sh

echo "rke2 uninstall script succeeded"
sudo /usr/local/bin/rke2-uninstall.sh &>/dev/null

echo "System agent uninstall script succeeded"
curl -sS https://raw.githubusercontent.com/rancher/system-agent/main/system-agent-uninstall.sh | sudo sh &>/dev/null

echo "Folder removal succeeded"
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

echo "iptables removal succeeded"
sudo iptables -t nat -X FLANNEL-POSTRTG &>/dev/null