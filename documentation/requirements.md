Cilium 

Key Requirements for Cilium with RKE2

    Kernel Version: Cilium requires a recent Linux kernel that supports the necessary eBPF functionality. The minimum requirement is generally kernel version 5.10 or later (or equivalent, like 4.18 on RHEL 8.6). Older kernels might lack certain eBPF features or have bugs that cause issues.
    Privileges: The cilium-agent pod requires significant privileges to interact with the kernel and install eBPF programs system-wide.
        It needs the CAP_SYS_ADMIN capability.
        The quickest way to meet this is to run the cilium-agent as a privileged container or as root.
        The Cilium pod typically runs in the host's networking namespace.
    BPF Filesystem Mount: The bpffs filesystem (BPF filesystem) must be mounted correctly on the host and within the cilium-agent pod.
        By default, the RKE2 Cilium Helm chart should handle this with bpf.autoMount=true.
        If autoMount is disabled, the user is responsible for ensuring bpffs is mounted at the specified bpf.root path on the host.
    Host Configuration:
        If NetworkManager is used, it should be configured to ignore CNI-managed interfaces.
        Swap should be disabled on all nodes. 

ubuntu@development:~$ uname -r
6.14.0-1015-gcp

ubuntu@development:~$ grep -E 'CONFIG_BPF|CONFIG_BPF_SYSCALL|CONFIG_BPF_EVENTS|CONFIG_BPF_JIT|CONFIG_XDP_SOCKETS' \
  /boot/config-$(uname -r)
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_JIT_DEFAULT_ON=y
CONFIG_BPF_UNPRIV_DEFAULT_OFF=y
# CONFIG_BPF_PRELOAD is not set
CONFIG_BPF_LSM=y
CONFIG_XDP_SOCKETS=y
CONFIG_XDP_SOCKETS_DIAG=m
CONFIG_BPF_STREAM_PARSER=y
CONFIG_BPF_EVENTS=y
CONFIG_BPF_KPROBE_OVERRIDE=y

ubuntu@development:~$ cat /proc/swaps
ubuntu@development:~$ swapon --show
ubuntu@development:~$ mount | grep -w bpf || echo "/sys/fs/bpf not mounted"
ubuntu@development:~$ ls -ld /sys/fs/bpf
ubuntu@development:~$ nmcli device status
bash: nmcli: command not found
ubuntu@development:~$ grep -R 'unmanaged-devices' /etc/NetworkManager/conf.d/ || \
> ^C
ubuntu@development:~$ grep -R 'unmanaged-devices' /etc/NetworkManager/conf.d/ || \
grep -R 'unmanaged-devices' /etc/NetworkManager/NetworkManager.conf
grep: /etc/NetworkManager/conf.d/: No such file or directory
grep: /etc/NetworkManager/NetworkManager.conf: No such file or directory
ubuntu@development:~$ kubectl -n kube-system get daemonset cilium -o yaml | \
  yq e '.spec.template.spec.containers[].securityContext' -
bash: yq: command not found
ubuntu@development:~$ kubectl -n kube-system get daemonset cilium -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.add}' | tr -d '[],'
ubuntu@development:~$ kubectl -n kube-system get daemonset cilium -o jsonpath='{.spec.template.spec.hostNetwork}'
ubuntu@development:~$ helm -n kube-system get values cilium
Error: release: not found
ubuntu@development:~$ ```bash
helm -n kube-system get values cilium | grep 'bpf.autoMount'
```
ubuntu@development:~$ helm -n kube-system get values cilium | grep 'bpf.autoMount'
Error: release: not found