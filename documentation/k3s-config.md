
k3s:
  docker: true
  containerRuntimeEndpoint: "/run/containerd/containerd.sock"
  imageServiceEndpoint: "localhost:5000"
  noFlannel: false
  selinux: false
  enablePProf: false
  supervisorMetrics: false
  embeddedRegistry: true
  flannelBackend: "vxlan"
  egressSelectorMode: "agent"
  token: "your-token-here"
  serverHTTPSPort: 6443
  supervisorPort: 10250
  defaultRuntime: "containerd"

etcd:
  accessKey: "your-access-key"
  bucket: "your-bucket-name"
  endpoint: "s3.amazonaws.com"
  insecure: false
  retention: 30

agent:
  nodeName: "your-node-name"
  clusterDNS: "10.43.0.10"
  clusterDomain: "cluster.local"
  serviceCIDR: "10.43.0.0/16"
  clusterCIDR: "10.42.0.0/16"
  nodeIP: "192.168.1.100"
  extraKubeletArgs:
    - "--kube-reserved=cpu=500m,memory=512Mi"
    - "--system-reserved=cpu=500m,memory=512Mi"
```

## Key Configuration Options Explained

1. **General Settings**: This section includes options for enabling Docker, setting the container runtime endpoint, and configuring Flannel networking.
2. **Etcd Configuration**: If using etcd for storage, this section includes S3 access details and retention settings for snapshots.
3. **Agent Configuration**: This section includes settings for the agent, such as node name, cluster DNS, and CIDR ranges.
