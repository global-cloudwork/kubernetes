# System Requirements

## Summary

When running Cilium using the container image `cilium/cilium`, the host system must meet these requirements:

- Hosts with either **AMD64** or **AArch64** architecture
- Linux kernel **>= 5.10** or equivalent (e.g., **4.18** on RHEL 8.10)

When running Cilium as a native process on your host (i.e. not running the `cilium/cilium` container image), these additional requirements must be met:

- clang+LLVM **>= 18.1**

When running Cilium without Kubernetes, these additional requirements must be met:

- Key-Value store **etcd >= 3.1.0**

| Requirement               | Minimum Version                       | In cilium container |
|---------------------------|---------------------------------------|---------------------|
| Linux kernel              | >= 5.10 or >= 4.18 on RHEL 8.10       | no                  |
| Key-Value store (etcd)    | >= 3.1.0                              | no                  |
| clang+LLVM                | >= 18.1                               | yes                 |

## Architecture Support

Cilium images are built for the following platforms:

- AMD64  
- AArch64

## Linux Distribution Compatibility & Considerations

The following table lists Linux distributions that are known to work well with Cilium. Some distributions require a few initial tweaks. Please read each distribution’s specific notes below before attempting to run Cilium.

| Distribution                 | Minimum Version           |
|------------------------------|---------------------------|
| Amazon Linux 2               | all                       |
| Bottlerocket OS              | all                       |
| CentOS                       | >= 8.6                    |
| Container-Optimized OS       | >= 85                     |
| Debian                       | >= 10 (Buster)            |
| Fedora CoreOS                | >= 31.20200108.3.0        |
| Flatcar                      | all                       |
| LinuxKit                     | all                       |
| openSUSE                     | Tumbleweed, >= Leap 15.4  |
| RedHat Enterprise Linux      | >= 8.6                    |
| RedHat CoreOS                | >= 4.12                   |
| Talos Linux                  | >= 1.5.0                  |
| Ubuntu                       | >= 20.04                  |

> **Note:**  
> The above list is based on user feedback. If you find an unlisted Linux distribution that works well, please let us know by opening a GitHub issue or creating a pull request.

### Flatcar on AWS EKS in ENI mode

Flatcar is known to manipulate network interfaces created and managed by Cilium. When running the official Flatcar image for AWS EKS nodes in ENI mode, this may cause connectivity issues and potentially prevent the Cilium agent from booting. To avoid this, disable DHCP on the ENI interfaces and mark them as unmanaged by adding:

```ini
[Match]
Name=eth[1-9]*

[Network]
DHCP=no

[Link]
Unmanaged=yes
```

to `/etc/systemd/network/01-no-dhcp.network` and then run:

```bash
systemctl daemon-reload
systemctl restart systemd-networkd
```

### Ubuntu 22.04 on Raspberry Pi

Before running Cilium on Ubuntu 22.04 on a Raspberry Pi, install the following package:

```bash
sudo apt install linux-modules-extra-raspi
```

## Linux Kernel

### Base Requirements

Cilium leverages and builds on the kernel eBPF functionality as well as various subsystems which integrate with eBPF. Host systems are required to run a recent Linux kernel to run a Cilium agent. More recent kernels may provide additional eBPF functionality that Cilium will automatically detect and use on agent start. For this version of Cilium, it is recommended to use kernel **5.10** or later (or equivalent such as **4.18** on RHEL 8.10). For a list of features that require newer kernels, see *Required Kernel Versions for Advanced Features* below.

In order for the eBPF feature to be enabled properly, the following kernel configuration options must be enabled. This is typically the case with distribution kernels. When an option can be built as a module or statically linked, either choice is valid.

```text
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_BPF=y
CONFIG_BPF_JIT=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
CONFIG_CRYPTO_SHA1=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
CONFIG_PERF_EVENTS=y
CONFIG_SCHEDSTATS=y
```

### Requirements for Iptables-based Masquerading

If you are not using BPF for masquerading (`enable-bpf-masquerade=false`, the default value), then you need the following kernel configuration options:

```text
CONFIG_NETFILTER_XT_SET=m
CONFIG_IP_SET=m
CONFIG_IP_SET_HASH_IP=m
CONFIG_NETFILTER_XT_MATCH_COMMENT=m
```

### Requirements for Tunneling and Routing

Cilium uses tunneling protocols like VXLAN by default for pod-to-pod communication across nodes, as well as policy routing for traffic management. The following kernel configuration options are required:

```text
CONFIG_VXLAN=y
CONFIG_GENEVE=y
CONFIG_FIB_RULES=y
```

> **Note:**  
> On some embedded or custom Linux systems, especially when cross-compiling for ARM, enabling `CONFIG_FIB_RULES=y` directly in the kernel `.config` is not sufficient, as it depends on other routing-related kernel options.  
> The recommended approach is to use:
> ```bash
> scripts/config --enable CONFIG_FIB_RULES
> make olddefconfig
> ```

### Requirements for L7 and FQDN Policies

L7 proxy redirection uses TPROXY iptables actions and socket matches. For L7 redirection you must enable:

```text
CONFIG_NETFILTER_XT_TARGET_TPROXY=m
CONFIG_NETFILTER_XT_TARGET_MARK=m
CONFIG_NETFILTER_XT_TARGET_CT=m
CONFIG_NETFILTER_XT_MATCH_MARK=m
CONFIG_NETFILTER_XT_MATCH_SOCKET=m
```

When the `xt_socket` kernel module is missing, a fallback compatibility mode is used (disabling `ip_early_demux` in non-tunneled datapath modes). To disable this fallback when HTTP or Kafka enforcement policies are not used:

```bash
helm install cilium ./cilium \
  --set enableXTSocketFallback=false
```

### Requirements for IPsec

The IPsec Transparent Encryption feature (GCM-128-AES) requires:

```text
CONFIG_XFRM=y
CONFIG_XFRM_OFFLOAD=y
CONFIG_XFRM_STATISTICS=y
CONFIG_XFRM_ALGO=m
CONFIG_XFRM_USER=m
CONFIG_INET{,6}_ESP=m
CONFIG_INET{,6}_IPCOMP=m
CONFIG_INET{,6}_XFRM_TUNNEL=m
CONFIG_INET{,6}_TUNNEL=m
CONFIG_INET_XFRM_MODE_TUNNEL=m
CONFIG_CRYPTO_AEAD=m
CONFIG_CRYPTO_AEAD2=m
CONFIG_CRYPTO_GCM=m
CONFIG_CRYPTO_SEQIV=m
CONFIG_CRYPTO_CBC=m
CONFIG_CRYPTO_HMAC=m
CONFIG_CRYPTO_SHA256=m
CONFIG_CRYPTO_AES=m
```

### Requirements for the Bandwidth Manager

```text
CONFIG_NET_SCH_FQ=m
```

### Requirements for Netkit Device Mode

```text
CONFIG_NETKIT=y
```

### Required Kernel Versions for Advanced Features

| Cilium Feature                                | Minimum Kernel Version |
|-----------------------------------------------|------------------------|
| Multicast Support in Cilium (Beta) (AMD64)    | >= 5.10                |
| IPv6 BIG TCP support                          | >= 5.19                |
| Multicast Support in Cilium (Beta) (AArch64)  | >= 6.0                 |
| IPv4 BIG TCP support                          | >= 6.3                 |

## Key-Value Store

Cilium optionally uses a distributed Key-Value store to manage, synchronize, and distribute security identities across all cluster nodes. Supported stores:

- etcd **>= 3.1.0**

Cilium can operate without a Key-Value store when CRD-based state management is used with Kubernetes (the default for new installations). Larger clusters perform better with a Key-Value store; see *Cilium Quick Installation* for more details.

## clang+LLVM

> **Note:** This requirement is only needed if you run `cilium-agent` natively. If you use the `cilium/cilium` container image, clang+LLVM is included.  
> LLVM is the compiler suite Cilium uses to generate eBPF bytecode.  
> Minimum supported version: **>= 18.1** (with eBPF backend enabled).  
> See https://releases.llvm.org/ for download and installation instructions.

## Firewall Rules

If your environment requires firewall rules to enable connectivity, ensure the following:

- ICMP Type 0/8 Code 0 open between nodes for `cilium-health` monitoring (optional).
- TCP 4240 open between nodes for health checks.
- For IPsec deployments, allow ESP traffic.
- For WireGuard, allow UDP port 51871.
- For VXLAN overlay (default), allow UDP port 8472.
- For Geneve overlay, allow UDP port 6081.
- In direct routing mode, allow routing of pod IPs.

### Example AWS Security Group Rules

#### Master Nodes (master-sg)

| Port/Protocol   | Ingress/Egress | Source/Destination | Description       |
|-----------------|----------------|--------------------|-------------------|
| 2379-2380/tcp   | ingress        | worker-sg          | etcd access       |
| 8472/udp        | ingress        | master-sg (self)   | VXLAN overlay     |
| 8472/udp        | ingress        | worker-sg          | VXLAN overlay     |
| 4240/tcp        | ingress        | master-sg (self)   | health checks     |
| 4240/tcp        | ingress        | worker-sg          | health checks     |
| ICMP 8/0        | ingress        | master-sg (self)   | health checks     |
| ICMP 8/0        | ingress        | worker-sg          | health checks     |
| 8472/udp        | egress         | master-sg (self)   | VXLAN overlay     |
| 8472/udp        | egress         | worker-sg          | VXLAN overlay     |
| 4240/tcp        | egress         | master-sg (self)   | health checks     |
| 4240/tcp        | egress         | worker-sg          | health checks     |
| ICMP 8/0        | egress         | master-sg (self)   | health checks     |
| ICMP 8/0        | egress         | worker-sg          | health checks     |

#### Worker Nodes (worker-sg)

| Port/Protocol   | Ingress/Egress | Source/Destination | Description       |
|-----------------|----------------|--------------------|-------------------|
| 8472/udp        | ingress        | master-sg          | VXLAN overlay     |
| 8472/udp        | ingress        | worker-sg (self)   | VXLAN overlay     |
| 4240/tcp        | ingress        | master-sg          | health checks     |
| 4240/tcp        | ingress        | worker-sg (self)   | health checks     |
| ICMP 8/0        | ingress        | master-sg          | health checks     |
| ICMP 8/0        | ingress        | worker-sg (self)   | health checks     |
| 8472/udp        | egress         | master-sg          | VXLAN overlay     |
| 8472/udp        | egress         | worker-sg (self)   | VXLAN overlay     |
| 4240/tcp        | egress         | master-sg          | health checks     |
| 4240/tcp        | egress         | worker-sg (self)   | health checks     |
| ICMP 8/0        | egress         | master-sg          | health checks     |
| ICMP 8/0        | egress         | worker-sg (self)   | health checks     |
| 2379-2380/tcp   | egress         | master-sg          | etcd access       |

> **Note:** A shared SG can condense rules to self. Direct routing mode can condense to ANY port/protocol to/from self.

The following ports should also be available on each node:

| Port/Protocol | Description                                |
|---------------|--------------------------------------------|
| 4240/tcp      | cluster health checks (cilium-health)      |
| 4244/tcp      | Hubble server                             |
| 4245/tcp      | Hubble Relay                              |
| 4250/tcp      | Mutual Authentication port                |
| 4251/tcp      | Spire Agent health check (127.0.0.1)      |
| 6060/tcp      | cilium-agent pprof server (127.0.0.1)      |
| 6061/tcp      | cilium-operator pprof server (127.0.0.1)   |
| 6062/tcp      | Hubble Relay pprof server (127.0.0.1)      |
| 9878/tcp      | cilium-envoy health listener (127.0.0.1)   |
| 9879/tcp      | cilium-agent health status API (127.0.0.1) |
| 9890/tcp      | cilium-agent gops server (127.0.0.1)       |
| 9891/tcp      | operator gops server (127.0.0.1)           |
| 9893/tcp      | Hubble Relay gops server (127.0.0.1)       |
| 9901/tcp      | cilium-envoy Admin API (127.0.0.1)         |
| 9962/tcp      | cilium-agent Prometheus metrics           |
| 9963/tcp      | cilium-operator Prometheus metrics        |
| 9964/tcp      | cilium-envoy Prometheus metrics           |
| 51871/udp     | WireGuard encryption tunnel endpoint      |

## Mounted eBPF filesystem

> **Note:** Some distributions mount the BPF filesystem automatically. Check:

```bash
mount | grep /sys/fs/bpf
# should output, e.g. “none on /sys/fs/bpf type bpf”
```

If not mounted, Cilium will automatically mount it. To manually mount before deployment:

```bash
mount bpffs /sys/fs/bpf -t bpf
```

For persistence, add to `/etc/fstab`:

```
bpffs /sys/fs/bpf bpf defaults 0 0
```

If using systemd for kubelet, see *Mounting BPFFS with systemd*.

## Routing Tables

When running in AWS ENI IPAM mode, Cilium installs per-ENI routing tables (ID = 10 + ENI index). These must not be used by other processes. Cilium uses:

| Routing Table ID | Purpose                       |
|------------------|-------------------------------|
| 200              | IPsec routing rules           |
| 202              | VTEP routing rules            |
| 2004             | Routing rules to the proxy    |
| 2005             | Routing rules from the proxy  |

## Privileges

Cilium requires:

- `CAP_SYS_ADMIN` to install eBPF programs (run as root or privileged container)
- Access to host networking namespace (pod runs with `hostNetwork: true`)

Ensure these privileges are granted when deploying.
