# GCE Bash Script Assessment

## Overall Readiness

The intended design is for the GCE VM to be the complete deployment host: a lightweight Linux instance should boot, pull this repository, install or start Kubernetes, and deploy the GitOps control plane and applications.

Against that goal, the current scripts are approximately **25% complete**. They provision the VM and implement much of the network gateway, but they do not yet turn the cloud instance into a Kubernetes deployment host.

## What Works

- Creates a GCE VPC, subnet, static IP, service account, firewall rules, and VM.
- Configures WireGuard, nftables, IP forwarding, Caddy, and IAP SSH access.
- Installs cert-manager, Argo CD, Source Hydrator support, and GitOps Promoter on a local Kind cluster.
- Injects GitHub credentials through protected files rather than storing them in Git.
- Bash syntax validation passes.

## Critical Gaps

1. The GCE VM is not yet a Kubernetes host. The provisioning script creates `e2-micro`, installs no Kubernetes distribution or container runtime, does not pull the repository, and does not deploy the GitOps stack. `bootstrap.sh` only creates a local Kind cluster.

There should be ain init script passed to the machine at create time to run on first boot deploying a on first login script to install the system. 


2. The startup script is supplied as GCE metadata key `user-data`. GCE normally executes `startup-script`; `user-data` requires cloud-init support in the selected image.

The user data is a hold out from previous versions, i would be aok with a decent secret system that would survive contact with git be made available. This was my attempt via google cloud. 

3. The requested instance size is not used. The script explicitly provisions `e2-micro`, not `e2-medium`. Even `e2-medium` may be tight for Argo CD, Promoter, Hydrator, cert-manager, Traefik, and the applications.

Medium. 

4. WireGuard state is ephemeral. Keys are generated at boot and stored under `/tmp`; rebooting changes the server identity and loses runtime-added peers.

No wireguard needed for the time being, we are pushing the whole server to the cloud so we can simply expose directly. 

5. The post-provision script hardcodes `us-central1` when retrieving the static IP, ignoring the configured region.

Yes. us central 1 a

6. Tunnel validation only checks that `wg0` exists. It does not verify peer handshakes or connectivity to LAN services.

no wireguard needed you can even remove the code from the sh files

7. The current cloud scripts configure a WireGuard/Caddy gateway, but do not invoke the Kubernetes Gateway and Argo CD architecture described in `agents.md`.

the gateway will allow us to expose via the external ip, the commands needed to get this working should be added to the sh run after the machine is logged in to for the first time. 

8. The current ApplicationSet discovers only Traefik, not the complete application catalog.

Develop the materials for each application, the various files needed should be sourced the most recent version and put in place. 


## Required Next Steps

- Choose and install a lightweight Kubernetes distribution on the GCE instance, such as k3s, and ensure it starts on reboot.

kind for simplicity

- Add a cloud bootstrap `sh` that installs prerequisites, clones or updates this repository, and runs the cloud Kubernetes bootstrap against the local cluster.

three sh, one local to make the instance
one on instance boot to pull an sh file and put it at the root with execute via chmod. 
user logs in runs sh at root done. 

- Change provisioning to the intended machine type, at minimum `e2-medium`.
- Use a valid GCE startup-script mechanism and verify it on the selected lightweight Linux image.
- Persist WireGuard server identity and peer configuration across reboots.
- Remove the hardcoded region and make post-provisioning use the configured GCP region.
This stuff should be in env. 
- Add real WireGuard handshake and service-connectivity tests.
- Split local Kind setup from cloud setup, or make the bootstrap script detect and target the local GCE cluster instead of creating Kind.
Call them clusters, for now we are only working on the cloud. 
- Expand ApplicationSet discovery once each application has a renderable source.
