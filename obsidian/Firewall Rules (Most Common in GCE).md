Google Cloud **VPC firewall rules** are the first place to check. Even if RKE2/Cilium configure internal rules, the GCE network firewall might block traffic.

- **API Server Port:** Ensure traffic is allowed to the control-plane node(s) on the **API server port** (default RKE2 is often 9345 or 6443, check your RKE2 config). This is needed for the kubelets and other management tools.
    
- **Inter-Node Communication:** Cilium needs full connectivity between nodes for its CNI overlay (often using VXLAN or Geneve on UDP 8472 by default) or BPF host routing. Ensure GCE firewall allows **all traffic** (or the specific CNI ports) between the **Node Internal IPs** on the VPC subnet.