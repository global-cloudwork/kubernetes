#!/bin/bash
#Everything Is Supressed

source <(curl -sSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/general.sh)


echo() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

function title() {
  command echo -e "\n\033[4m\033[38;5;11m# $1\033[0m"
}

function header() {
    command echo -e "\n\033[4m\033[38;5;9m## $1\033[0m"
}

title "Removing Existing RKE2 Resources"

header "remove symbolic links before re-installing"
rm $HOME/.kube/
sudo rm /usr/local/bin/kubectl

header "rke2 scripts, kill all and uninstall"
sudo /usr/local/bin/rke2-killall.sh
sudo /usr/local/bin/rke2-uninstall.sh

header "System agent uninstall script"
curl -sS https://raw.githubusercontent.com/rancher/system-agent/main/system-agent-uninstall.sh | sudo sh &>/dev/null

header "Folder removal"
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

header "iptables removal (optional but good for a fresh start)"
sudo iptables -t nat -X FLANNEL-POSTRTG &>/dev/null
sudo iptables -t nat -F &>/dev/null # Optional: Also flush the NAT table entirely

