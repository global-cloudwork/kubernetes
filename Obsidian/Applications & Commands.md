| Tool                    | Purpose                                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Argo CD**             | A GitOps continuous delivery tool that automatically deploys applications to Kubernetes based on changes in a Git repository.      |
| **Cilium**              | A CNI (Container Network Interface) providing advanced networking, security, and observability for Kubernetes using eBPF.          |
| **RKE2**                | A secure and streamlined Kubernetes distribution by Rancher, optimized for production and edge environments.                       |
| **Cert-Manager**        | Automates the management and issuance of TLS/SSL certificates within Kubernetes clusters.                                          |
| **Kubernetes**          | The container orchestration platform for deploying, scaling, and managing containerized applications.                              |
| **kubectl**             | The official Kubernetes command-line tool used to interact with the cluster (deploy apps, inspect resources, manage workloads).    |
| **helm**                | A package manager for Kubernetes that simplifies deploying and managing applications using reusable “Helm charts.”                 |
| **Hubble**              | The observability platform for Cilium — provides network flow visibility, service dependency graphs, and security policy insights. |
| **Google CLI (gcloud)** | Command-line tool for managing Google Cloud Platform resources, including Kubernetes Engine (GKE) clusters.                        |
| **curl**                | A command-line tool for making HTTP requests — useful for testing APIs, health checks, and network troubleshooting.                |
| **bash**                | The standard Unix shell and scripting language used for automation, scripting, and running CLI commands.                           |
### **1. `kubectl`**

`kubectl` is the Kubernetes CLI for interacting with the cluster. It’s used for managing resources, applying manifests, checking logs, and configuring kubeconfig.

Examples:

- `kubectl apply -f <file_or_url>` → Applies a manifest to the cluster.
    
- `kubectl logs -n <namespace> <pod>` → Fetches logs from a pod.
    
- `kubectl config view --flatten` → Merges kubeconfig files.
    

---

### **3. `curl`**

`curl` is a tool to fetch data from URLs. In your script, it’s used to download scripts, manifests, and configuration files from GitHub or Google metadata.

Examples:

- `curl --silent --show-error https://raw.githubusercontent.com/... | bash` → Downloads and executes a remote script.
    
- `curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/...` → Fetches instance metadata.
    

---

### **4. `gcloud`**

`gcloud` is the Google Cloud CLI. It’s used to interact with GCP services, such as fetching secrets.

Examples:

- `gcloud secrets versions access latest --secret=development-env-file` → Retrieves the latest version of a secret.
    
- `gcloud secrets versions access latest --secret="dns-solver-json-key" --project="global-cloudworks"` → Fetches a specific secret for DNS challenge.
    

### **6. `apt` / `apt-get`**

These are Debian/Ubuntu package managers used to install system dependencies.

Examples:

- `sudo apt-get -qq update` → Updates package lists quietly.
    
- `sudo apt-get -qq -y install git wireguard` → Installs git and wireguard non-interactively.
    
- `sudo apt install ./k9s_linux_amd64.deb` → Installs a downloaded `.deb` package.
    

---

### **7. `envsubst`**

`envsubst` replaces environment variables in a file with their values.

Example:

- `sudo --preserve-env envsubst < /tmp/config.yaml | sudo tee /etc/rancher/rke2/config.yaml` → Injects environment variables into RKE2 config.
    

---

### **8. `tee`**

`tee` writes output to a file and optionally to stdout. Often used to write as root via `sudo`.

Example:

- `sudo tee /etc/rancher/rke2/config.yaml` → Writes the processed config file.
    

---

### **9. `systemctl`**

`systemctl` manages system services on Linux.

Examples:

- `sudo systemctl enable rke2-server.service` → Enables service on boot.
    
- `sudo systemctl restart rke2-server.service` → Restarts the service.
    

---

### **10. `mkdir`**

`mkdir` creates directories.

Example:

- `sudo mkdir -p /etc/rancher/rke2/` → Creates the RKE2 config directory.
    

---

### **11. `ln`**

`ln` creates symbolic links.

Example:

- `sudo ln -s /var/lib/rancher/rke2/bin/kubectl /usr/local/bin/kubectl` → Makes kubectl globally accessible.
    

---

### **12. `cp` / `chown`**

File copy and ownership commands.

Examples:

- `sudo cp -f /etc/rancher/rke2/rke2.yaml ...` → Copies kubeconfig.
    
- `sudo chown "$USER":"$USER" "$HOME/.kube/$CLUSTER_NAME/config"` → Ensures correct permissions.
    

---

### **13. `find` / `paste`**

Used to locate files and manipulate lists.

Example:

- `KUBECONFIG_LIST=$(find -L /home/ubuntu/.kube -mindepth 2 -type f -name config | paste -sd:)` → Finds all kubeconfig files and concatenates them.
    

---

### **14. `wait_for`**

This seems to be a custom function (probably from the sourced scripts) that waits for certain Kubernetes resources (like CRDs or endpoints) to be ready.

---

### **15. `header` / `section` / `title`**

These are custom functions (likely from the sourced scripts) used for printing readable sections and headers in the logs.

---

### **16. `rm`**

Deletes files.

Example:

- `rm k9s_linux_amd64.deb` → Cleans up downloaded package.
    

---

### **17. `awk`**

Text processing tool.

Example:

- `hostname -I | awk '{print $1}'` → Gets the first IP of the host.
    

---

### **18. `bash`**

Used to execute scripts fetched via `curl`.

Example:

- `curl ... | bash` → Runs the remote script immediately.