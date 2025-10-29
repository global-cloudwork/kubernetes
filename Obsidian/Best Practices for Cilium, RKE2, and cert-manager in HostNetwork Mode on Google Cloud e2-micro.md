

## Overview of HostNetwork Mode in Kubernetes

Running pods with `hostNetwork: true` binds them directly to the node’s network namespace and IP, bypassing the overlay CNI. This eliminates the veth/NAT overhead and can **improve network throughput and latency**, but it also merges pod and host networking (with attendant risks). In limited-resource environments (e.g. GCP e2-micro: ~1 GB RAM, ~1 vCPU burst), hostNetwork may reduce CPU/memory use from network virtualization[alibabacloud.com](https://www.alibabacloud.com/blog/kubedl-hostnetwork-accelerating-communication-efficiency-for-distributed-training_599068#:~:text=set%20the%20scale%20and%20characteristic,Efficiency%20Is). However, it introduces port-conflict risks (multiple pods sharing the host IP) and weaker network isolation. For example, hostNetwork pods can’t have overlapping port assignments, and failover/restart of a hostNetwork pod can require updating clients or load-balancers to the new host port[alibabacloud.com](https://www.alibabacloud.com/blog/kubedl-hostnetwork-accelerating-communication-efficiency-for-distributed-training_599068#:~:text=KubeDL%20extends%20the%20communication%20model,performance%20networks). In general, hostNetwork mode should be used only when needed for performance or connectivity (e.g. control-plane reachability), and with careful port planning.

## Cilium (CNI) Implications in HostNetwork Mode

- **Pod Networking and Policies:** Cilium’s datapath typically manages individual pod veth interfaces. Pods on hostNetwork share the node’s IP and **are not managed by Cilium’s normal datapath**, so they do not get a `CiliumEndpoint` and are not subject to Cilium KubernetesNetworkPolicies by default[docs.cilium.io](https://docs.cilium.io/en/stable/operations/troubleshooting/#:~:text=,false%20or%20use%20Host%20Policies). In practice this means hostNetwork pods have _full network access_ unless explicitly restricted. To secure them, use Cilium’s **HostFirewall**/Host-Policies (CiliumClusterwideNetworkPolicy with `nodeSelector`) to enforce L3/L4 rules at the node level[docs.cilium.io](https://docs.cilium.io/en/stable/operations/troubleshooting/#:~:text=,false%20or%20use%20Host%20Policies)[cncf.io](https://www.cncf.io/blog/2025/09/03/securing-the-node-a-primer-on-ciliums-host-firewall/#:~:text=Feature%20Cilium%20Network%20Policy%20Cilium,networked%20pods). For example, a host-policy could restrict ingress to only authorized CIDRs or ports. Without host-policies, hostNetwork pods can bypass network policies entirely.
    
- **Observability:** Cilium’s Hubble flow logs **do not automatically capture** hostNetwork pod traffic, since no CiliumEndpoint exists[flagzeta.org](https://flagzeta.org/til/pods-that-use-host-network-are-not-subject-to-network-policies/#:~:text=Pods%20that%20use%20host%20network,not%20subject%20to%20network%20policies). HostNetwork traffic appears as host-level flows. To monitor it, enable Cilium’s host firewall in **audit or log mode**, or use node-level packet capture. Hubble can filter on the node identity (node ID “1”) to see host traffic, but by default hostNetwork pods themselves won’t show up as “endpoint flows” in Hubble. Plan to monitor hostNetwork components via host-based logging or node-exporter metrics rather than pod flows.
    
- **Network Behavior:** Since hostNetwork pods share the node’s physical interface, they bypass any CNI encapsulation (no VXLAN/IPIP). This means true native routing is used, improving throughput[alibabacloud.com](https://www.alibabacloud.com/blog/kubedl-hostnetwork-accelerating-communication-efficiency-for-distributed-training_599068#:~:text=set%20the%20scale%20and%20characteristic,Efficiency%20Is). However, without overlay encapsulation, pods won’t move between nodes while keeping the same IP; if a hostNetwork pod restarts on another node, clients must reach the new host IP/port. To mitigate this, use Services/LoadBalancers with nodePort/hostPort abstractions or IP failover tooling. Also ensure the node’s kernel routing tables can handle the intended traffic (e.g. appropriate `iptables` or eBPF rules for NodePort, though kube-proxy may be disabled under Cilium’s eBPF mode).
    
- **Port Conflicts:** The node’s ports become a shared resource. Notably, **ingress controllers or other daemons may already bind common ports**. For example, RKE2’s default NGINX Ingress binds host ports 80/443[docs.rke2.io](https://docs.rke2.io/networking/networking_services#:~:text=%60ingress,NodePort%20services%20in%20the%20cluster). Avoid assigning hostNetwork pods to these ports, or disable/change the default ingress. Similarly, cert-manager’s webhook (running on hostNetwork) must avoid port 10250 (kubelet)[cert-manager.io](https://cert-manager.io/docs/troubleshooting/webhook/#:~:text=By%20setting%20,pod%20IPs%20nor%20cluster%20IPs). Always audit which host ports are in use (e.g. `ss -tlpn`) before enabling new hostNetwork pods, and pick non-conflicting ports.
    

## RKE2 (Rancher Kubernetes Engine 2) on GCP e2-micro

- **Resource Constraints:** RKE2 is designed to run a full Kubernetes control plane, and officially **recommends ≥2 vCPUs and ≥4 GB RAM**[docs.rke2.io](https://docs.rke2.io/install/requirements#:~:text=Linux%2FWindows). An e2-micro (1 GB, ~0.25 CPU sustained per vCPU) is well under that baseline. In practice, expect significant memory and CPU pressure. To cope, run a **single-server (single-node) cluster** and disable unneeded components. For example, use RKE2’s embedded SQLite datastore instead of etcd to save resources – it’s not HA but is suitable for a small, short-lived cluster[docs.rke2.io](https://docs.rke2.io/datastore/embedded#:~:text=Embedded%20SQLite). To enable SQLite, set `disable-etcd: true` in the RKE2 server config. This removes the overhead of an etcd pod.
    
- **Networking and Host Ports:** Assign the static external IP to the RKE2 server instance and configure GCP firewall rules for the Kubernetes ports. RKE2 requires that port **6443** (Kubernetes API) and **9345** (RKE2 agent) be reachable by other nodes[docs.rke2.io](https://docs.rke2.io/install/requirements#:~:text=The%20RKE2%20server%20needs%20port,other%20nodes%20in%20the%20cluster). If using Canal/Flannel, also allow UDP **8472** for VXLAN; if using Cilium with `kube-proxy` disabled, ensure control-plane services (DNS, etc) are reachable. Note that RKE2’s default NGINX Ingress binds host ports 80 and 443[docs.rke2.io](https://docs.rke2.io/networking/networking_services#:~:text=%60ingress,NodePort%20services%20in%20the%20cluster). If hostNetwork pods (or any pods) need these ports, either disable the default ingress chart or configure an alternative port/service. Otherwise, these ports are “taken” on the node.
    
- **Node Configuration:** Disable or tailor system services that interfere with CNI. For example, ensure NetworkManager or firewalld do not override CNI-managed interfaces[docs.rke2.io](https://docs.rke2.io/install/requirements#:~:text=If%20your%20node%20has%20NetworkManager,installed%20and%20enabled%2C%20%2032). On an e2-micro you may skip complex networking; using plain Debian/Ubuntu with cloud-init is typical. Keep the OS lean (disable GUI). Consider setting resource limits on RKE2 system pods (etcd, kube-apiserver, coredns) so they cannot exhaust memory.
    
- **DNS and Load Balancing:** Use CoreDNS as usual. If DNS latency or throughput is a concern, consider NodeLocal DNS Cache (despite needing iptables or Cilium LRP) to reduce upstream queries. For external services, since the VM has a static IP, outbound traffic uses that IP by default (no extra NAT needed). For inbound, you can either use that IP directly (with firewall) or set up a TCP/UDP Network Load Balancer pointing to the node.
    

## cert-manager in HostNetwork Mode

- **Webhook Connectivity:** The cert-manager **webhook pod** often needs hostNetwork in environments where the API server cannot directly reach Pod IPs (e.g. private clusters or custom networks). Enabling hostNetwork for the webhook makes it accessible on the node IP, allowing the API server to connect via the node’s address[cert-manager.io](https://cert-manager.io/docs/troubleshooting/webhook/#:~:text=By%20setting%20,pod%20IPs%20nor%20cluster%20IPs). When doing so, change the webhook’s `securePort` from the default 10250 to avoid colliding with the kubelet’s port on the host[cert-manager.io](https://cert-manager.io/docs/troubleshooting/webhook/#:~:text=By%20setting%20,pod%20IPs%20nor%20cluster%20IPs). For example, set `webhook.securePort=10260`. If using Helm or kustomize, ensure you override the port in the cert-manager HelmChartConfig. After enabling hostNetwork, make sure the GCP firewall allows the API server node to reach that port on worker nodes.
    
- **Other Pods:** The **cert-manager controller and cainjector** typically do not require hostNetwork; keep them in normal pod networking to preserve isolation. Limit hostNetwork to only the webhook pod unless other special needs arise.
    
- **Certificates and Security:** Even in hostNetwork mode, cert-manager security best practices apply. Use minimal RBAC bindings, and do not expose its admission webhooks broadly. Keep cert-manager up-to-date, but avoid tying documentation to a specific version.
    

## Google Cloud Network Considerations

- **Static External IP:** With a static external IP on the instance, all egress traffic (including hostNetwork pods) will originate from that IP. Ensure any required egress (e.g. ACME servers on 80/443 for certificates) is permitted by GCP’s default egress rules (usually open). If additional NAT is needed (e.g. for multiple nodes), consider Cloud NAT or assigning static IPs to each node.
    
- **Firewall Rules:** By default, Google Cloud blocks inbound traffic. Create firewall rules to allow the required ports on the node’s static IP: Kubernetes ports (6443, 9345), Cilium/CNI ports if any (e.g. VXLAN), and any service ports (e.g. 80/443 if exposing via ingress). Remember that hostNetwork pods listen on the node’s IP, so GCP must allow traffic to those ports on the VM. Restrict source ranges where possible (e.g. only your office or other cluster nodes).
    
- **Port Conflicts:** Because hostNetwork pods share the same host IP, carefully map services. If you need multiple services on the same standard port, consider running additional proxies or mapping to different host ports. For instance, if ingress-nginx uses 80/443, any other service (e.g. a second ingress or cert-manager webhook) must use alternate ports on the node. Document port usage to avoid silent conflicts.
    

## Security and Compliance

- **Isolation:** HostNetwork mode reduces network namespace isolation. PodSecurity standards regard `hostNetwork: true` as **privileged** (it bypasses network restrictions). As a best practice, allow only trusted system pods (ingress, kube-proxy, monitoring) to use hostNetwork, and keep application pods in default networking. Use Kubernetes Pod Security Admission to prohibit arbitrary hostNetwork pods, if possible.
    
- **Node Firewall (Cilium Host Policies):** Use Cilium’s host firewall feature to lock down node-level traffic[cncf.io](https://www.cncf.io/blog/2025/09/03/securing-the-node-a-primer-on-ciliums-host-firewall/#:~:text=Feature%20Cilium%20Network%20Policy%20Cilium,networked%20pods). For example, allow only essential ports (SSH, API server, NodePort services) and drop the rest. Run Cilium’s host policies in audit mode first to avoid cutting off the API or SSH[cncf.io](https://www.cncf.io/blog/2025/09/03/securing-the-node-a-primer-on-ciliums-host-firewall/#:~:text=,when%20writing%20and%20debugging%20policies). Additionally, label nodes (e.g. `node-role.kubernetes.io/worker`) and write CiliumClusterwideNetworkPolicies scoped to these labels.
    
- **Cluster Components:** Protect the RKE2 control plane (etcd, API) with TLS and firewall. Even on a single node, ensure etcd (if used) is not listening on public interfaces. For cert-manager, protect its webhook port with Firewall rules and possibly restrict access to the control-plane subnet.
    
- **Compliance Auditing:** In a constrained cluster, logs and metrics may be minimal. Ship critical logs off-node if compliance requires (e.g. Cloud Logging for kube-apiserver and kubelet). Enable Kubernetes audit logging (even if only to disk) to track hostNetwork pod activity. Use GCP’s VPC Flow Logs if network traffic auditing is needed.
    

## Observability and Monitoring

- **Host vs Pod Metrics:** Standard Kubernetes metrics (via kubelet/metrics-server) apply only to pods in normal networking. For hostNetwork pods, monitor them as node processes. For instance, if the ingress-nginx pod is hostNetwork, its resource usage appears in the DaemonSet and in `top` on the node.
    
- **Cilium/Hubble:** As noted, Hubble flow logs won’t list hostNetwork pods. Still, run Cilium Hubble for the rest of the cluster. For the host, use Cilium’s eBPF metrics (`cilium status`) or Linux tools (tcpdump) to inspect traffic. If feasible, deploy Hubble Relay with a bucket backend to offload logs (bearing in mind the e2-micro’s limited memory).
    
- **Application Logs:** Collect logs from critical components (Cilium, RKE2, cert-manager) to a central place (e.g. Stackdriver Logging). If running a logging agent is too heavy, periodically `kubectl logs` and push or use `gcloud logging write` from the node.
    
- **Health Checks:** Use Kubernetes readiness and liveness probes as usual. For hostNetwork pods, ensure probes use `hostIP` (Kubelets do this automatically). For example, cert-manager’s webhook on hostNetwork still has a Service; ensure its port matches the host port so the API server health-checks it correctly.
    

## Configuration and Operational Tips

- **Limit Add-ons:** On an e2-micro, disable non-essential add-ons (metrics-server if you don’t use HPA, second ingress controllers, monitoring agents, etc.) to conserve resources.
    
- **Resource Requests/Limits:** Define modest requests for system pods. For example, set Cilium agent requests to low values. Avoid bursting beyond the CPU credit of the e2-micro (monitor with `top` or Cloud Monitoring alerts).
    
- **Upgrade Caution:** Because hostNetwork and minimal resources is a fragile setup, test upgrades carefully. Always have an alternative access (e.g. SSH to node) if a misconfiguration causes Kubernetes API loss.
    
- **Documentation:** Clearly document which pods run hostNetwork and on which host ports. Include this in any automation (Terraform, Ansible) so future operators or AI systems understand the mapping.
    
- **High Availability:** True HA is unrealistic on e2-micro. Plan for occasional downtime and manual recovery. Store cluster credentials (e.g. RKE2 tokens, kubeconfig) securely in case you must rebuild.
    

By following these practices, you can run a lightweight RKE2/Cilium/cert-manager cluster on a tiny GCP VM with hostNetwork pods. The key is to **minimize resource usage and carefully manage the shared node network namespace**, while securing and monitoring the few hostNetwork services you enable. Each decision (enabling hostNetwork, choosing ports, scaling components) should be driven by necessity and documented for repeatability and audit.