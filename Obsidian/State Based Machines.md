---
title: Empty Swimlane Diagram
---

%% You can rename or add participants and steps as needed
%% Use |Lane Name| to define swimlanes

```mermaid
architecture-beta

%% Internet zone

group internet_zone(internet)[Internet]

service client_pc(cloud)[Client] in internet_zone

  

%% GCP Cloud grouping

group gcp_zone(cloud)[GCP Cloud]

service ext_ip(cloud)[External IP] in gcp_zone

  

%% Ephemeral Compute Instance with components

group ephemeral_compute(server)[Ephemeral Compute Instance] in gcp_zone

service gateway(cloud)[Gateway] in ephemeral_compute

service httproute(server)[HTTPRoute] in ephemeral_compute

service clusterissuer(cloud)[ClusterIssuer] in ephemeral_compute

service appsvc(server)[Service] in ephemeral_compute

  

%% Arrow connections as requested

client_pc:R --> L:ext_ip

ext_ip:R --> L:gateway

gateway:R --> L:httproute

httproute:R --> L:appsvc
```

Internet
   │
   ▼
[GCP External IP / LoadBalancer]
   │
   ▼
[Compute Instance NIC]
   │
   ▼
[Cilium eBPF / Network Policy]
   │
   ▼
[Envoy Proxy]
   │
   ▼
[Gateway API Listener] -- TLS via ClusterIssuer
   │
   ├──> [HTTPRoute 1] --> [Service 1 / Pod]
   ├──> [HTTPRoute 2] --> [Service 2 / Pod]
   ├──> [HTTPRoute 3] --> [Service 3 / Pod]
   └──> [HTTPRoute 4] --> [Service 4 / Pod]
   │
   ▼
Response flows back