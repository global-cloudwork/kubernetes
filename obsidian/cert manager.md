### Network Requirements[](https://cert-manager.io/docs/installation/best-practice/#network-requirements)

Here is an overview of the network requirements:

1. **UDP / TCP: cert-manager (all) -> Kubernetes DNS**: All cert-manager components perform UDP DNS queries for both cluster and external domain names. Some DNS queries may use TCP.
    
2. **TCP: Kubernetes (API server) -> cert-manager (webhook)**: The Kubernetes API server establishes HTTPS connections to the [cert-manager webhook component](https://cert-manager.io/docs/concepts/webhook/). Read the cert-manager [webhook troubleshooting guide](https://cert-manager.io/docs/troubleshooting/webhook/) to understand the webhook networking requirements.
    
3. **TCP: cert-manager (webhook, controller, cainjector, startupapicheck) -> Kubernetes API server**: The cert-manager webhook, controller, cainjector and startupapicheck establish HTTPS connections to the Kubernetes API server, to interact with cert-manager custom resources and Kubernetes resources. The cert-manager webhook is a special case; it connects to the Kubernetes API server to use the `SubjectAccessReview` API, to verify clients attempting to modify `Approved` or `Denied` conditions of `CertificateRequest` resources.
    
4. **TCP: cert-manager (controller) -> HashiCorp Vault (authentication and resource API endpoints)**: The cert-manager controller may establish HTTPS connections to one or more Vault API endpoints, if you are using the [Vault Issuer](https://cert-manager.io/docs/configuration/vault/). The target host and port of the Vault endpoints are configured in Issuer or ClusterIssuer resources.
    
5. **TCP: cert-manager (controller) -> CyberArk Certificate Manager (authentication and resource API endpoints)**: The cert-manager controller may establish HTTPS connections to one or more CyberArk Certificate Manager API endpoints, if you are using the [CyberArk Issuer](https://cert-manager.io/docs/configuration/venafi/). The target host and port of the CyberArk Certificate Manager endpoints are configured in Issuer or ClusterIssuer resources.
    
6. **TCP: cert-manager (controller) -> DNS API endpoints (for ACME DNS01)**: The cert-manager controller may establish HTTPS connections to DNS API endpoints such as Amazon Route53, and to any associated authentication endpoints, if you are using the [ACME Issuer with DNS01 solvers](https://cert-manager.io/docs/configuration/acme/dns01/#supported-dns01-providers).
    
7. **UDP / TCP: cert-manager (controller) -> External DNS**: If you use the ACME Issuer, the cert-manager controller may send DNS queries to recursive DNS servers, as part of the ACME challenge self-check process. It does this to ensure that the DNS01 or HTTP01 challenge is resolvable, before asking the ACME server to perform its checks.
    
    In the case of DNS01 it may also perform a series of DNS queries to authoritative DNS servers, to compute the DNS zone in which to add the DNS01 challenge record. In the case of DNS01, cert-manager also [supports DNS over HTTPS](https://cert-manager.io/docs/releases/release-notes/release-notes-1.13/#dns-over-https-doh-support).
    
    You can choose the host and port of the DNS servers, using the following [controller flags](https://cert-manager.io/docs/cli/controller/): `--acme-http01-solver-nameservers`, `--dns01-recursive-nameservers`, and `--dns01-recursive-nameservers-only`.
    
8. **TCP: ACME (Let's Encrypt) -> cert-manager (acmesolver)**: If you use an ACME Issuer configured for HTTP01, cert-manager will deploy an `acmesolver` Pod, a Service and an Ingress (or Gateway API) resource in the namespace of the Issuer or in the cert-manager namespace if it is a ClusterIssuer. The ACME implementation will establish an HTTP connection to this Pod via your chosen ingress load balancer, so your network policy must allow this.
    
    > ℹ️ The acmesolver Pod **does not** require access to the Kubernetes API server.
    
9. **TCP: Metrics Collector -> cert-manager (controller, webhook, cainjector)**: The cert-manager controller, webhook, and cainjector have metrics servers which listen for HTTP connections on TCP port 9402. Create a network policy which allows access to these services from your chosen metrics collector.