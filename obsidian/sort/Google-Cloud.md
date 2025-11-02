---
title: "Google Cloud"
service: "Google Cloud"
gcloud_cli_usage: "Used locally to create a compute instance with a static external IP"
compute_instance:
  static_ip: true
  entry_point: true
secrets:
  - wireguard_key
  - dns_challenge_key
  - env_vars_file
service_accounts:
  primary:
    role: "instance-launcher"
    permissions:
      - "access_secrets"
  secondary:
    role: "dns_challenge_handler"
    permissions:
      - "manage_dns_challenges"
---

# Google Cloud

Detailed configuration for provisioning and securing the main compute instance and related secrets.
