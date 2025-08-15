#!/bin/bash
echo "Remove RKE2"
curl https://raw.githubusercontent.com/rancher/system-agent/main/system-agent-uninstall.sh | sudo sh
/usr/local/bin/rke2-killall.sh
/usr/local/bin/rke2-uninstall.sh

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
       /var/run/calico

sudo iptables -t nat -X FLANNEL-POSTRTG