## What is Gateway API?[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#what-is-gateway-api "Permalink to this heading")

Gateway API is a Kubernetes SIG-Network subproject to design a successor for the Ingress object. It is a set of resources that model service networking in Kubernetes, and is designed to be role-oriented, portable, expressive, and extensible.

See the [Gateway API site](https://gateway-api.sigs.k8s.io/) for more details.

## Cilium Gateway API Support[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#cilium-gateway-api-support "Permalink to this heading")

Cilium supports Gateway API v1.2.0 for below resources, all the Core conformance tests are passed.

- [GatewayClass](https://gateway-api.sigs.k8s.io/api-types/gatewayclass/)
    
- [Gateway](https://gateway-api.sigs.k8s.io/api-types/gateway/)
    
- [HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/)
    
- [GRPCRoute](https://gateway-api.sigs.k8s.io/api-types/grpcroute/)
    
- [TLSRoute (experimental)](https://gateway-api.sigs.k8s.io/references/spec/#gateway.networking.k8s.io/v1alpha2.TLSRoute)
    
- [ReferenceGrant](https://gateway-api.sigs.k8s.io/api-types/referencegrant/)
    

Additionally, Cilium provides `CiliumGatewayClassConfig` CRD, which can be referenced in [GatewayClass.parametersRef](https://gateway-api.sigs.k8s.io/api-types/gatewayclass/#gatewayclass-parameters).

Video

> If you’d like more insights on Cilium’s Gateway API support, check out [eCHO episode 58: Cilium Service Mesh and Ingress](https://www.youtube.com/watch?v=60epwCxO8G4&index=80&t=2024s).

## Prerequisites[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#prerequisites "Permalink to this heading")

- Cilium must be configured with NodePort enabled, using `nodePort.enabled=true` or by enabling the kube-proxy replacement with `kubeProxyReplacement=true`. For more information, see [kube-proxy replacement](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#kubeproxy-free).
    
- Cilium must be configured with the L7 proxy enabled using `l7Proxy=true` (enabled by default).
    
- The below CRDs from Gateway API v1.2.0 `must` be pre-installed. Please refer to this [docs](https://gateway-api.sigs.k8s.io/guides/?h=crds#getting-started-with-gateway-api) for installation steps. Alternatively, the below snippet could be used.
    
    > - [GatewayClass](https://gateway-api.sigs.k8s.io/api-types/gatewayclass/)
    >     
    > - [Gateway](https://gateway-api.sigs.k8s.io/api-types/gateway/)
    >     
    > - [HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/)
    >     
    > - [GRPCRoute](https://gateway-api.sigs.k8s.io/api-types/grpcroute/)
    >     
    > - [ReferenceGrant](https://gateway-api.sigs.k8s.io/api-types/referencegrant/)
    >     
    
    If you wish to use the TLSRoute functionality, you’ll also need to install the TLSRoute resource. If this CRD is not installed, then Cilium will disable TLSRoute support.
    
    > - [TLSRoute (experimental)](https://gateway-api.sigs.k8s.io/references/spec/#gateway.networking.k8s.io%2fv1alpha2.TLSRoute/)
    >     
    
    You can install the required CRDs like this:
    
    > kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
    > kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
    > kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
    > kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
    > kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
    
    And add TLSRoute with this snippet.
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
    
- By default, the Gateway API controller creates a service of LoadBalancer type, so your environment will need to support this. Alternatively, since Cilium 1.16+, you can directly expose the Cilium L7 proxy on the [host network](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#gs-gateway-host-network-mode).
    

## Installation[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#installation "Permalink to this heading")

Install the latest version of the Cilium CLI. The Cilium CLI can be used to install Cilium, inspect the state of a Cilium installation, and enable/disable various features (e.g. clustermesh, Hubble).

LinuxmacOSOther

CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

HelmCilium CLI

Cilium Gateway API Controller can be enabled with helm flag `gatewayAPI.enabled` set as true. Please refer to [Installation using Helm](https://docs.cilium.io/en/stable/installation/k8s-install-helm/#k8s-install-helm) for a fresh installation.

$ helm upgrade cilium cilium/cilium --version 1.18.3 \
    --namespace kube-system \
    --reuse-values \
    --set kubeProxyReplacement=true \
    --set gatewayAPI.enabled=true

$ kubectl -n kube-system rollout restart deployment/cilium-operator
$ kubectl -n kube-system rollout restart ds/cilium

Next you can check the status of the Cilium agent and operator:

cilium status

## Reference[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#reference "Permalink to this heading")

### How Cilium Ingress and Gateway API differ from other Ingress controllers[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#how-cilium-ingress-and-gateway-api-differ-from-other-ingress-controllers "Permalink to this heading")

One of the biggest differences between Cilium’s Ingress and Gateway API support and other Ingress controllers is how closely tied the implementation is to the CNI. For Cilium, Ingress and Gateway API are part of the networking stack, and so behave in a different way to other Ingress or Gateway API controllers (even other Ingress or Gateway API controllers running in a Cilium cluster).

Other Ingress or Gateway API controllers are generally installed as a Deployment or Daemonset in the cluster, and exposed via a Loadbalancer Service or similar (which Cilium can, of course, enable).

Cilium’s Ingress and Gateway API config is exposed with a Loadbalancer or NodePort service, or optionally can be exposed on the Host network also. But in all of these cases, when traffic arrives at the Service’s port, eBPF code intercepts the traffic and transparently forwards it to Envoy (using the TPROXY kernel facility).

This affects things like client IP visibility, which works differently for Cilium’s Ingress and Gateway API support to other Ingress controllers.

It also allows Cilium’s Network Policy engine to apply CiliumNetworkPolicy to traffic bound for and traffic coming from an Ingress.

### Cilium’s ingress config and CiliumNetworkPolicy[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#cilium-s-ingress-config-and-ciliumnetworkpolicy "Permalink to this heading")

Ingress and Gateway API traffic bound to backend services via Cilium passes through a per-node Envoy proxy.

The per-node Envoy proxy has special code that allows it to interact with the eBPF policy engine, and do policy lookups on traffic. This allows Envoy to be a Network Policy enforcement point, both for Ingress (and Gateway API) traffic, and also for east-west traffic via GAMMA or L7 Traffic Management.

However, for ingress config, there’s also an additional step. Traffic that arrives at Envoy _for Ingress or Gateway API_ is assigned the special `ingress` identity in Cilium’s Policy engine.

Traffic coming from outside the cluster is usually assigned the `world` identity (unless there are IP CIDR policies in the cluster). This means that there are actually _two_ logical Policy enforcement points in Cilium Ingress - before traffic arrives at the `ingress` identity, and after, when it is about to exit the per-node Envoy.

![../../../../_images/ingress-policy.png](https://docs.cilium.io/en/stable/_images/ingress-policy.png)

This means that, when applying Network Policy to a cluster, it’s important to ensure that both steps are allowed, and that traffic is allowed from `world` to `ingress`, and from `ingress` to identities in the cluster (like the `productpage` identity in the image above).

Please see the [Ingress and Network Policy Example](https://docs.cilium.io/en/stable/network/servicemesh/ingress-and-network-policy/#gs-ingress-and-network-policy) for more details for Ingress, although the same principles also apply for Gateway API.

### Source IP Visibility[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#source-ip-visibility "Permalink to this heading")

Note

By default, source IP visibility for Cilium ingress config, both Ingress and Gateway API, should _just work_ on most installations. Read this section for more information on requirements and relevant settings.

Having a backend be able to deduce what IP address the actual request came from is important for most applications.

By default, Cilium’s Envoy instances are configured to append the visible source address of incoming HTTP connections to the `X-Forwarded-For` header, using the usual rules. That is, by default Cilium sets the number of trusted hops to `0`, indicating that Envoy should use the address the connection is opened from, rather than a value inside the `X-Forwarded-For` list. Increasing this count will have Envoy use the `n` th value from the list, counting from the right.

Envoy will also set the `X-Envoy-External-Address` header to the trusted client address, whatever that turns out to be, based on `X-Forwarded-For`.

Note

Backends using Cilium ingress (whether via Ingress or Gateway API) should just see the `X-Forwarded-For` and `X-Envoy-External-Address` headers (which are handled transparently by many HTTP libraries).

#### `externalTrafficPolicy` for Loadbalancer or NodePort Services[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#externaltrafficpolicy-for-loadbalancer-or-nodeport-services "Permalink to this heading")

Cilium’s ingress support (both for Ingress and Gateway API) often uses a Loadbalancer or NodePort Service to expose the Envoy Daemonset.

In these cases, the Service object has one field that is particularly relevant to Client IP visibility - the `externalTrafficPolicy` field.

It has two relevant settings:

- `Local`: Nodes will only route traffic to Pods running on the local node, _without masquerading the source IP_. Because of this, in clusters that use `kube-proxy`, this is the only way to ensure source IP visibility. Part of the contract for `externalTrafficPolicy` local is also that the node will open a port (the `healthCheckNodePort`, automatically set by Kubernetes when `externalTrafficPolicy: Local` is set), and requests to `http://<nodeIP>:<healthCheckNodePort>/healthz` will return 200 on nodes that have local pods running, and non-200 on nodes that don’t. Cilium implements this for general Loadbalancer Services, but it’s a bit different for Cilium ingress config (both Ingress and Gateway API).
    
- `Cluster`: Node will route to all endpoints across the cluster evenly. This has a couple of other effects: Firstly, upstream loadbalancers will expect to be able to send traffic to any node and have it end up at a backend Pod, and the node _may_ masquerade the source IP. This means that in many cases, `externalTrafficPolicy: Cluster` may mean that the backend pod does _not_ see the source IP.
    

In Cilium’s case, all ingress traffic bound for a Service that exposes Envoy is _always_ going to the local node, and is _always_ forwarded to Envoy using the Linux Kernel TPROXY function, which transparently forwards packets to the backend.

This means that for Cilium ingress config, for both Ingress and Gateway API, things work a little differently in both `externalTrafficPolicy` cases.

Note

In _both_ `externalTrafficPolicy` cases, traffic will arrive at any node in the cluster, and be forwarded to _Envoy_ **while keeping the source IP intact**.

Also, for any Services that exposes Cilium’s Envoy, Cilium will ensure that when `externalTrafficPolicy: Local` is set, every node in the cluster will pass the `healthCheckNodePort` check, so that external load balancers will forward correctly.

However, for Cilium’s ingress config, both Ingress and Gateway API, **it is not necessary** to configure `externalTrafficPolicy: Local` to keep the source IP visible to the backend pod (via the `X-Forwarded-For` and `X-Envoy-External-Address` fields).

#### TLS Passthrough and source IP visibility[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#tls-passthrough-and-source-ip-visibility "Permalink to this heading")

Both Ingress and Gateway API support TLS Passthrough configuration (via annotation for Ingress, and the TLSRoute resource for Gateway API). This configuration allows multiple TLS Passthrough backends to share the same TLS port on a loadbalancer, with Envoy inspecting the Server Name Indicator (SNI) field of the TLS handshake, and using that to forward the TLS stream to a backend.

However, this poses problems for source IP visibility, because Envoy is doing a TCP Proxy of the TLS stream.

What happens is that the TLS traffic arrives at Envoy, terminating a TCP stream, Envoy inspects the client hello to find the SNI, picks a backend to forward to, then starts a new TCP stream and forwards the TLS traffic inside the downstream (outside) packets to the upstream (the backend).

Because it’s a new TCP stream, as far as the backends are concerned, the source IP is Envoy (which is often the Node IP, depending on your Cilium config).

Note

When doing TLS Passthrough, backends will see Cilium Envoy’s IP address as the source of the forwarded TLS streams.

### [[Host network mode]][](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#host-network-mode "Permalink to this heading")

Note

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

#### Deploy Gateway API listeners on subset of nodes[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#deploy-gateway-api-listeners-on-subset-of-nodes "Permalink to this heading")

The Cilium Gateway API Envoy listener can be exposed on a specific subset of nodes. This only works in combination with the host network mode and can be configured via a node label selector in the Helm values:

gatewayAPI:
  enabled: true
  hostNetwork:
    enabled: true
    nodes:
      matchLabels:
        role: infra
        component: gateway-api

This will deploy the Gateway API Envoy listener only on the Cilium Nodes matching the configured labels. An empty selector selects all nodes and continues to expose the functionality on all Cilium nodes.

### Gateway API Addresses Support[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#gateway-api-addresses-support "Permalink to this heading")

Cilium Gateway supports [Addresses](https://gateway-api.sigs.k8s.io/api-types/gateway/?h=addresses) provided by the Gateway API specification. The `spec.addresses` field is used to specify the IP address of the gateway.

Note

The feature only supports IPAddress type of addresses, and works with the LB-IPAM. Please see [LoadBalancer IP Address Management (LB IPAM)](https://docs.cilium.io/en/stable/network/lb-ipam/#lb-ipam) for more information.

apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  addresses:
  - type: IPAddress
    value: 172.18.0.140
  gatewayClassName: cilium
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: web-gw
    port: 80
    protocol: HTTP

The output of the above configuration will be:

kubectl get gateway my-gateway
NAME         CLASS    ADDRESS        PROGRAMMED   AGE
my-gateway   cilium   172.18.0.140   True         2d7h

If you are already using the `io.cilium/lb-ipam-ips` in the `spec.infrastructure.annotations` to specify the IP, the `spec.addresses` field will be ignored.

apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  infrastructure:
    annotations:
      io.cilium/lb-ipam-ips: "172.18.0.141"
  addresses: # This will be ignored
  - type: IPAddress
    value: 172.18.0.140
  gatewayClassName: cilium
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: web-gw
    port: 80
    protocol: HTTP

The output of the above configuration will be:

kubectl get gateway my-gateway
NAME         CLASS    ADDRESS        PROGRAMMED   AGE
my-gateway   cilium   172.18.0.141   True         2d7h

Note

At a future date the use of the `io.cilium/lb-ipam-ips` will be deprecated, and then after that, this annotation will be ignored if no `spec.addresses` are set. In both cases, warning logs will be added to the Cilium agent logs, and a warning Condition will be placed on the Gateway.

## Examples[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#examples "Permalink to this heading")

Please refer to one of the below examples on how to use and leverage Cilium’s Gateway API features:

- [HTTP Example](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/http/)
- [HTTPS Example](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/https/)
- [gRPC Example](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/grpc/)
- [Traffic Splitting Example](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/splitting/)
- [HTTP Header Modifier Examples](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/header/)
- [GatewayClass Parameters Support](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/parameterized-gatewayclass/)

More examples can be found in the [upstream repository](https://github.com/kubernetes-sigs/gateway-api/tree/v1.2.0/examples/standard).

## Troubleshooting[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#troubleshooting "Permalink to this heading")

This page guides you through the different mechanics of Gateway API and how to troubleshoot them.

Be sure to follow the Generic and Setup Verification steps from the [Troubleshooting Ingress & Service Mesh page](https://docs.cilium.io/en/stable/operations/troubleshooting/#troubleshooting-servicemesh).

### Checking resources[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#checking-resources "Permalink to this heading")

1. Check the Gateway resource
    
    > kubectl get gateway -A
    > NAMESPACE                   NAME                 CLASS    ADDRESS          PROGRAMMED   AGE
    > website                     http-gateway         cilium   172.21.255.202   True         5h
    > webshop                     tls-gateway          cilium   172.21.255.203   True         5h
    > 
    > The preceding command returns an overview of all the Gateways in the cluster. Check the following:
    > 
    > - Is the Gateway programmed?
    >     
    >     > A programmed Gateway means that Cilium prepared a configuration for it.
    >     
    >     - If the `Programmed true` indicator is missing, make sure that Gateway API is enabled in the Cilium configuration.
    >         
    > - Does the gateway have an address?
    >     
    > 
    > You can check the service with `kubectl get service`. If the gateway has an address, it means that a LoadBalancer service is assigned to the gateway. If no IP appears, you might be missing a LoadBalancer implementation.
    > 
    > - Is the class `cilium`?
    >     
    > 
    > Cilium only programs Gateways with the class `cilium`.
    > 
    > - If the Gateway API resource type (`Gateway`, `HTTPRoute`, etc.) is not found, make sure that the Gateway API CRDs are installed.
    >     
    > 
    > You can use `kubectl describe gateway` to investigate issues more thoroughly.
    > 
    > kubectl describe gateway <name>
    > 
    >   Conditions:
    >     Message:               Gateway successfully scheduled
    >     Reason:                Accepted
    >     Status:                True
    >     Type:                  Accepted
    >     Message:               Gateway successfully reconciled
    >     Reason:                Programmed
    >     Status:                True
    >     Type:                  Programmed
    >     [...]
    >   Listeners:
    >     Attached Routes:  2
    >     Conditions:
    >       Message:               Listener Ready
    >       Reason:                Programmed
    >       Status:                True
    >       Type:                  Programmed
    >       Message:               Listener Accepted
    >       Reason:                Accepted
    >       Status:                True
    >       [...]
    > 
    > You can see the general status of the gateway as well as the status of the configured listeners.
    > 
    > Listener status displays the number of routes successfully attached to the listener.
    > 
    > You can see status conditions for both gateway and listener:
    > 
    > > - `Accepted`: the Gateway configuration was accepted.
    > >     
    > > - `Programmed`: the Gateway configuration was programmed into Envoy.
    > >     
    > > - `ResolvedRefs`: all referenced secrets were found and have permission for use.
    > >     
    > 
    > If any of these conditions are set to false, the `Message` and `Reason` fields give more information.
    
2. Check the HTTPRoute resource
    

> When the Gateway is functional, you can check the routes to verify if they are configured correctly. The way to check route status is similar to checking the status of a gateway resource.
> 
> While these instructions are written for HTTPRoute, they also apply to other route types.
> 
> kubectl get httproute -A
> NAMESPACE                 NAME              HOSTNAMES         AGE
> website                   homepage          www.example.org   17m
> webshop                   catalog-service                     17m
> webshop                   cart-service                        17m
> 
> To get more information, enter `kubectl describe httproute <name>`.
> 
> kubectl describe httproute <name>
> Status:
>   Parents:
>     Conditions:
>       Last Transition Time:  2023-06-05T15:11:53Z
>       Message:               Accepted HTTPRoute
>       Observed Generation:   1
>       Reason:                Accepted
>       Status:                True
>       Type:                  Accepted
>       Last Transition Time:  2023-06-05T15:11:53Z
>       Message:               Service reference is valid
>       Observed Generation:   1
>       Reason:                ResolvedRefs
>       Status:                True
>       Type:                  ResolvedRefs
>     Controller Name:         io.cilium/gateway-controller
>     Parent Ref:
>       Group:  gateway.networking.k8s.io
>       Kind:   Gateway
>       Name:   same-namespace
> 
> Status lists the conditions that are relevant for the specific `HTTPRoute`. Conditions are listed by parent reference to the gateway. If you linked the route to multiple gateways, multiple entries appear. Conditions include `Reason`, `Type`, `Status` and `Message`. `Type` indicates the condition type, and `Status` indicates with a boolean whether the condition type is met. Optionally, `Message` gives you more information about the condition.
> 
> Notice the following condition types:
> 
> - `Accepted`: The HTTPRoute configuration was correct and accepted.
>     
> - `ResolvedRefs`: The referenced services were found and are valid references.
>     
> 
> If any of these are set to false, you can get more information by looking at the `Message` and `Reason` fields.

1. Check Cilium Operator logs
    

> The Cilium Operator logs may contain further debugging information. For example, if the required Custom Resource Definitions (CRDs) are not installed, an error will be logged:
> 
> kubectl logs -n kube-system deployments/cilium-operator | grep gateway
> level=error msg="Required GatewayAPI resources are not found, please
> refer to docs for installation instructions" error="customresourcedefinitions.apiextensions.k8s.io \"gatewayclasses.gateway.networking.k8s.io\" not found
> customresourcedefinitions.apiextensions.k8s.io \"gateways.gateway.networking.k8s.io\" not found
> customresourcedefinitions.apiextensions.k8s.io \"httproutes.gateway.networking.k8s.io\" not found
> customresourcedefinitions.apiextensions.k8s.io \"referencegrants.gateway.networking.k8s.io\" not found
> customresourcedefinitions.apiextensions.k8s.io \"grpcroutes.gateway.networking.k8s.io\" not found
> customresourcedefinitions.apiextensions.k8s.io \"tlsroutes.gateway.networking.k8s.io\" not found" subsys=gateway-api

### Common mistakes[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#common-mistakes "Permalink to this heading")

Warning

Gateway API is a recent addition to Kubernetes, and the Cilium project has not yet received much user feedback. If you encounter an issue that is not yet listed in this section, consider opening a PR to add your issue to the list.

- The backend service does not exist.
    
    > To verify whether the backend service was found, run `kubectl describe httproute <name>` and inspect the `conditions` field:
    
    Parents:
      Conditions:
        Last Transition Time:  2023-06-06T13:55:10Z
        Message:               Service "backend" not found
        Observed Generation:   1
        Reason:                BackendNotFound
        Status:                False
        Type:                  ResolvedRefs
        Last Transition Time:  2023-06-06T13:55:10Z
        Message:               Accepted HTTPRoute
        Observed Generation:   1
        Reason:                Accepted
        Status:                True
        Type:                  Accepted
      Controller Name:         io.cilium/gateway-controller
    
- The gateway specified under `parentRefs` does not exist.
    
    > To verify whether the gateway was found, run `kubectl describe httproute <name>` and inspect the `conditions` field:
    

Parents:
  Conditions:
    Last Transition Time:  2023-06-06T13:56:40Z
    Message:               Gateway.gateway.networking.k8s.io "my-gateway" not found
    Observed Generation:   2
      Reason:                InvalidHTTPRoute
      Status:                False
      Type:                  Accepted

### Underlying mechanics: a high level overview[](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/#underlying-mechanics-a-high-level-overview "Permalink to this heading")

A Cilium deployment has two parts that handle Gateway API resources: the Cilium agent and the Cilium operator.

The Cilium operator watches all Gateway API resources and verifies whether the resources are valid. If resources are valid, the operator marks them as accepted. That starts the process of translation into Cilium Envoy Configuration resources.

The Cilium agent then picks up the Cilium Envoy Configuration resources.

The Cilium agent uses the resources to supply the configuration to the built in Envoy or the Envoy DaemonSet. Envoy handles traffic.