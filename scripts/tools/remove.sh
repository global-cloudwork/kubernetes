#!/bin/bash
#Everything Is Supressed

echo() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

function h1() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

function h2() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

h1 "Removing Existing RKE2 Resources"

h2 "remove symbolic links before re-installing"
rm $HOME/.kube/config
sudo rm /usr/local/bin/kubectl

h2 "rke2 kill all script"
sudo /opt/rke2/bin/rke2-killall.sh

h2 "rke2 uninstall script"
sudo /opt/rke2/bin/rke2-uninstall.sh

h2 "System agent uninstall script"
curl -sS https://raw.githubusercontent.com/rancher/system-agent/main/system-agent-uninstall.sh | sudo sh &>/dev/null

h2 "Folder removal"
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

h2 "iptables removal (optional but good for a fresh start)"
# Flushes the specific NAT chain created by Flannel/CNI
sudo iptables -t nat -X FLANNEL-POSTRTG &>/dev/null
sudo iptables -t nat -F &>/dev/null # Optional: Also flush the NAT table entirely

