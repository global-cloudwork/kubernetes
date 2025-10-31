**Role / Purpose:**

- Acts primarily as a cloud gateway to terminate tls and expose dashboards.
- Deploys on an ephemeral Ubuntu virtual machine in Google Cloud.
- Connects as an agent using wireguard, to a cluster on site.
- Hosts a gateway, cluster-issuer, and httproutes deployed using argocd.
- Handles DNS challenge to authorize https traffic.

Key Applications
- Argocd
	- Applicationset
		- Matrix generator 
			- scm generator file discovery
			- clusters
- cert-manager 
	- Allows for gateway annotation to automate certificates for each httproute
	- Allows our cluster-issuer to authenticate using a google service account dns challenge.


Deployed using the [[RKE2 & Cilium Boostrap]] it exposes a [[Gateway]] using [[Host network mode]]

[[Debugging]] can be done using the following commands:
- sudo ss -tulnp
	- Allows you to find out what is exposed on the host.


## Networking Architecture

RKE2 first deploys itself without a CNI, afterwards networking crds are applied and Cilium is installed using helm with it's gateway api flag set, and in host network mode allowing the gateway to bind to 0.0.0.0.

This is advantageous because in google cloud compute, you are given an external and internal ip address for the machine. Also of note is that an internal load balencer is not needed.

The traffic enters the cluster using the endpoint for the gateway, then passes through via http route to the various services exposing pods inside of kubernetes. 






                                                               
- **Cilium-related services:**
    
    - You now see several `LISTEN` entries related to Cilium (e.g., `cilium-envoy` on ports `9964`, `9878`).
        
    - This means that Cilium's networking components (including Envoy) are now running and bound to ports for communication.
        
- **Kubernetes-related services:**
    
    - Ports like `10257`, `10258`, `10259`, `10248`, and `6443` are all Kubernetes components (controller manager, scheduler, kubelet, API server).
        
    - The presence of ports like `2379` and `2380` on `10.128.15.231` indicate that `etcd` is running, which is essential for Kubernetes.
        
- **Cilium Agent:**
    
    - There is an entry for `cilium-envoy` on port `9964` and `9878`. These ports are used by Cilium for Envoy proxy and networking-related tasks.
        
- **Kubelet and Kube API Server:**
    
    - Ports like `10250` for `kubelet` and `9345` for `rke2` are now showing up. This indicates the kubelet and RKE2 services are active.

![[Debug Method]]