# Cilium System Requirements

Before installing Cilium, ensure your system meets these requirements. Most modern Linux distributions already do.

---

## 1. CPU Architecture
- **Requirement:** AMD64 or AArch64
- **Reason:** Cilium container images are built for these architectures. Using an unsupported CPU will prevent the agent from running.

---

## 2. Linux Kernel
- **Minimum Version:** >= 5.10 (or >= 4.18 on RHEL 8.6)
- **Reason:** Required for eBPF support. Older kernels may lack necessary eBPF functionality.

### Essential Kernel Modules/Options:
- `CONFIG_BPF=y` → Basic BPF support  
- `CONFIG_BPF_SYSCALL=y` → Allows cilium-agent to load eBPF programs  
- `CONFIG_NET_CLS_BPF=y` → Packet classification for BPF  
- `CONFIG_BPF_JIT=y` → JIT compilation for eBPF programs, improving performance  
- `CONFIG_NET_CLS_ACT=y` → Enables BPF actions in traffic control  
- `CONFIG_NET_SCH_INGRESS=y` → Needed for ingress traffic shaping  
- `CONFIG_CRYPTO_SHA1=y` → Required for certain encryption operations  
- `CONFIG_CRYPTO_USER_API_HASH=y` → User-space access to crypto hashes  
- `CONFIG_CGROUPS=y` and `CONFIG_CGROUP_BPF=y` → Required for cgroup-based BPF programs  
- `CONFIG_PERF_EVENTS=y` → Enables performance monitoring  
- `CONFIG_SCHEDSTATS=y` → Allows tracking of scheduler statistics  

### Optional / Special Kernel Requirements:
- **Iptables Masquerading:** Needed only if BPF masquerade is **disabled**.  
- **Tunneling & Routing:** Required if using VXLAN/Geneve or policy routing.  
- **L7 / FQDN Policies:** Required for HTTP/Kafka layer-7 policies. Fallback exists if `xt_socket` is missing (performance may decrease).  
- **IPsec Encryption:** Required only if using **IPsec Transparent Encryption**.  
- **Bandwidth Manager:** Required to manage bandwidth shaping.  
- **Netkit Device Mode:** Required if using netkit devices.  

### Advanced Features Kernel Versions:
- Multicast (AMD64) → >= 5.10  
- IPv6 BIG TCP → >= 5.19  
- Multicast (AArch64) → >= 6.0  
- IPv4 BIG TCP → >= 6.3  

---

## 3. Key-Value Store
- **Requirement:** `etcd >= 3.1.0` (if not using Kubernetes)  
- **Reason:** Distributes security identities across nodes. Kubernetes CRDs can replace etcd, but etcd improves performance in large clusters.

---

## 4. clang+LLVM
- **Requirement:** `>= 18.1` (for native agent installation only)  
- **Reason:** Needed to generate eBPF bytecode dynamically. Not required in containerized deployment, as LLVM is included.

---

## 5. Linux Distribution Compatibility
| Distribution | Minimum Version |
|--------------|----------------|
| Amazon Linux 2 | all |
| Bottlerocket OS | all |
| CentOS | >= 8.6 |
| Container-Optimized OS | >= 85 |
| Debian | >= 10 Buster |
| Fedora CoreOS | >= 31.20200108.3.0 |
| Flatcar | all |
| LinuxKit | all |
| OpenSUSE | Tumbleweed, >= Leap 15.4 |
| RHEL | >= 8.6 |
| RHCOS | >= 4.12 |
| Talos Linux | >= 1.5.0 |
| Ubuntu | >= 20.04 |

**Special Notes:**  
- **Flatcar on AWS EKS ENI mode:** Disable DHCP on Cilium-managed interfaces to prevent interface conflicts.  
- **Ubuntu 22.04 on Raspberry Pi:** Install `linux-modules-extra-raspi` for required kernel modules.

---

## 6. Firewall Rules
- Required only in restricted network environments.  
- **Minimum:** ICMP ping and TCP 4240 for cilium-health.  
- **Additional requirements based on features:**
  - **IPsec:** Allow ESP traffic  
  - **WireGuard:** Allow UDP 51871  
  - **VXLAN overlay:** UDP 8472 (or 6081 for Geneve)  
- **Reason:** Ensures inter-node communication, overlay networks, and security features function correctly.

---

## 7. Mounted eBPF Filesystem
- **Requirement:** `/sys/fs/bpf` must be mounted.  
- **Reason:** Stores eBPF programs to persist across agent restarts.  
- **Optional:** Persistent mount via `/etc/fstab` recommended.

---

## 8. Routing Tables
- **Requirement:** For AWS ENI IPAM, per-ENI routing tables must not conflict with main routing tables (253–255).  
- **Reason:** Cilium installs custom routing tables (index 10 + ENI index) for pod IP allocation.

---

## 9. Privileges
- **Requirement:** `CAP_SYS_ADMIN` or root/privileged container.  
- **Reason:** Needed to load eBPF programs and access host networking namespace.

---

## 10. Ports
- Standard node ports required for Cilium operations (Hubble, metrics, health, WireGuard, VXLAN).  
- **Reason:** Required for communication, monitoring, and overlay networks. Open only if the features are used.