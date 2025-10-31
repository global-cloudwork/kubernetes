---
title: "Edge"
gateway:
  static_ip: true
  ports:
    - 80
    - 443
  annotations:
    cert_manager_enabled: true
    annotation_key: "cert-manager.io/cluster-issuer"
tls_termination: true
cluster_issuer:
  acme:
    challenge: "DNS-01"
    dns_provider: "Google Cloud DNS"
  secret_key: "dns_challenge_key"
  project: "<google_cloud_project>"
  runtime_key_file: "key.json"
  service_account: "dns_challenge_handler"
namespace: "gateway"
---

# Edge

Configuration for the gateway and ClusterIssuer supporting HTTPS route management.

## Gateway  
- Listens on the instance’s static external IP for ports 80 (HTTP) and 443 (HTTPS).  
- Annotated (`cert-manager.io/cluster-issuer`) so Cert-Manager will automatically create and manage TLS certificates.  
- TLS connections terminate at the gateway; certificate references handled by the annotation.

## ClusterIssuer  
- Uses ACME DNS-01 challenge via Google Cloud DNS.  
- Reads `dns_challenge_key` from Google Secrets to generate `key.json` at runtime.  
- Service account (`dns_challenge_handler`) has permissions to update DNS records.  
- Employs the Google Cloud project name and key file to provision certificates for all HTTP routes defined in application directories.
