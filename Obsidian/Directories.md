### **1. RKE2 Installation & Runtime Directories**

These are used by RKE2 itself:

- **`/etc/rancher/rke2/`**
    
    - Contains RKE2 configuration files.
        
    - Example: `config.yaml` is placed here.
        
- **`/var/lib/rancher/rke2/bin`**
    
    - Contains RKE2 binaries (kubectl, rke2, etc.).
        
- **`/var/lib/rancher/rke2/server/manifests/`**
    
    - Directory for static manifests for RKE2 server (manifests deployed at startup).
        

---

### **2. Kubeconfig Directories**

Used for storing cluster access credentials:

- **`$HOME/.kube/$CLUSTER_NAME/`** (e.g., `$HOME/.kube/cloud-proxy/`)
    
    - Stores the cluster-specific kubeconfig.
        
- **`$HOME/.kube/`**
    
    - Central location for merged kubeconfig files.
        
    - Used for the `KUBECONFIG` environment variable.