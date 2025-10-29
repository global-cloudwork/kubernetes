Supported since Cilium 1.16+

Host network mode allows you to expose the Cilium Gateway API Gateway directly on the host network. This is useful in cases where a LoadBalancer Service is unavailable, such as in development environments or environments with cluster-external loadbalancers.

Note

- Enabling the Cilium Gateway API host network mode automatically disables the LoadBalancer type Service mode. They are mutually exclusive.
    
- The listener is exposed on all interfaces (`0.0.0.0` for IPv4 and/or `::` for IPv6).
    

Host network mode can be enabled via Helm:

gatewayAPI:
  enabled: true
  hostNetwork:
    enabled: true

Once enabled, the host network port for a `Gateway` can be specified via `spec.listeners.port`. The port must be unique per `Gateway` resource and you should choose a port number higher than `1023` (see [Bind to privileged port](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#bind-to-privileged-port)).

Warning

Be aware that misconfiguration might result in port clashes. Configure unique ports that are still available on all Cilium Nodes where Gateway API listeners are exposed.

#### Bind to privileged port[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#bind-to-privileged-port "Permalink to this heading")

By default, the Cilium L7 Envoy process does not have any Linux capabilities out-of-the-box and is therefore not allowed to listen on privileged ports.

If you choose a port equal to or lower than `1023`, ensure that the Helm value `envoy.securityContext.capabilities.keepCapNetBindService=true` is configured and to add the capability `NET_BIND_SERVICE` to the respective [Cilium Envoy container via Helm values](https://docs.cilium.io/en/stable/security/network/proxy/envoy/#envoy):

- Standalone DaemonSet mode: `envoy.securityContext.capabilities.envoy`
    
- Embedded mode: `securityContext.capabilities.ciliumAgent`
    

Configure the following Helm values to allow privileged port bindings in host network mode:

Standalone DaemonSet modeEmbedded mode

gatewayAPI:
  enabled: true
  hostNetwork:
    enabled: true
envoy:
  enabled: true
  securityContext:
    capabilities:
      keepCapNetBindService: true
      envoy:
      # Add NET_BIND_SERVICE to the list (keep the others!)
      - NET_BIND_SERVICE