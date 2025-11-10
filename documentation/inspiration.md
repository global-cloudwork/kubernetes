write-kubeconfig-mode: "0644"
advertise-address: 10.1.2.183

cni: "none"
cluster-cidr: "10.32.0.0/15"
service-cidr: "10.42.0.0/15"
cluster-dns: "10.42.0.10"

etcd-expose-metrics: true
etcd-arg: "--quota-backend-bytes 2048000000"
etcd-snapshot-schedule-cron: "0 3 * * *"
etcd-snapshot-retention: 10

disable-cloud-controller: true
disable-kube-proxy: true

disable:
  - rke2-ingress-nginx
  - rke2-metrics-server
  - rke2-snapshot-controller
  - rke2-snapshot-controller-crd
  - rke2-snapshot-validation-webhook

tls-san:
  - <node-ip>
  - <node-fqdn>
  - <vip-dns-name>

node-taint:
  - "CriticalAddonsOnly=true:NoExecute"

kube-apiserver-arg:
  - '--default-not-ready-toleration-seconds=30'
  - '--default-unreachable-toleration-seconds=30'
kube-controller-manager-arg:
  - '--node-monitor-period=4s'
kubelet-arg:
  - '--node-status-update-frequency=4s'
  - '--max-pods=100'

egress-selector-mode: disabled

