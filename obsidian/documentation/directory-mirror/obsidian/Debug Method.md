The `external`, `internal`, `advertise`, `k8shost`, and `k8shostport` variables are often used by RKE2 and Cilium to manage how network traffic is routed.

To check the values for these IPs:

## Networking

1. **External IP and Internal IP**: The IP used to access the node externally, usually the IP associated with the public-facing network interface.
	1. ip addr show
2. **Advertise IP**: This is the IP that is advertised to other nodes or used for communication. It may be configured in the RKE2 settings under `advertise-address`.
	1. cat /etc/rancher/rke2/config.yaml
3. **K8S Host IP and Port**:
	1. kubectl cluster-info
4. **Exposures On Host**
	1. sudo ss -tulnp


ip addr show
cat /etc/rancher/rke2/config.yaml
kubectl cluster-info
sudo ss -tulnp


## Pods 


```bash
for pod in $(kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed 's/ */,/g'); do
	NAMESPACE=$(echo $pod | cut -d',' -f1)
	NAME=$(echo $pod | cut -d',' -f2)
	echo "--- Checking logs for $NAMESPACE/$NAME ---"
	kubectl logs -n $NAMESPACE $NAME --tail=500 2>/dev/null | grep -i error
	echo
done
```