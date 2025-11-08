# System Requirements[](https://docs.cilium.io/en/stable/operations/system_requirements/#system-requirements "Permalink to this heading")

Summary from system requirements. 

## Core System Requirements 💻

- **Architecture:** Your GCE node must use **AMD64** or **AArch64** architecture.
    
- **Linux Kernel:** The host Linux kernel version must be **≥5.10** or equivalent (e.g., ≥4.18 on RHEL 8.6).
    
    - **Kernel Configuration:** The kernel must have eBPF-related options enabled, including:
        
        - `CONFIG_BPF=y`
            
        - `CONFIG_BPF_SYSCALL=y`
            
        - `CONFIG_NET_CLS_BPF=y`
            
        - `CONFIG_BPF_JIT=y`
            
        - And other required base/tunneling options (like `CONFIG_VXLAN=y`, `CONFIG_GENEVE=y`, `CONFIG_FIB_RULES=y`).
            

---

## Deployment & Privilege Requirements ⚙️

- **Deployment Method:** Since you're using a Helm install, Cilium will run as the **`cilium/cilium` container image** (typically as a Kubernetes DaemonSet).
    
    - **No** separate **`clang+LLVM`** installation is required on the host, as it's included in the container.
        
- **Key-Value Store:** **No** external Key-Value store (like **etcd ≥3.1.0**) is strictly required, as Cilium defaults to using **Kubernetes CRD-based state management** for identity.
    
- **Privileges:** The `cilium-agent` must be run as a **privileged container** with **`CAP_SYS_ADMIN`** capabilities and must operate within the **host networking namespace**. (This is typically handled automatically by the standard Cilium DaemonSet definition).
    
- **eBPF Filesystem:** The **eBPF filesystem** must be mounted on the host at `/sys/fs/bpf`. Cilium will attempt to mount it automatically if it's not present.
    

---

## Network & Firewall Requirements 🌐

Assuming a default **VXLAN overlay** network mode for cross-node Pod communication, the following ports must be open between all cluster nodes in your GCE VPC firewall:

- **VXLAN Tunneling:** **UDP port 8472** (Ingress and Egress).
    
- **Health Checks:** **TCP port 4240** and **ICMP Type 0/8, Code 0** (Ingress and Egress)