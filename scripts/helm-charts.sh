
# --- Actual Budget ---
mkdir -p ../kubernetes/actualbudget
helm repo add community-charts https://community-charts.github.io/helm-charts
helm install my-actualbudget community-charts/actualbudget --version 1.8.0
# Output YAML manifests for Actual Budget
helm template my-actualbudget community-charts/actualbudget --version 1.8.0 > ../kubernetes/actualbudget/my-actualbudget.yaml
# Pull values.yaml for Actual Budget
helm show values community-charts/actualbudget --version 1.8.0 > ../kubernetes/actualbudget/my-actualbudget.values.yaml

 # --- Vaultwarden ---
mkdir -p ../kubernetes/vaultwarden
helm repo add gissilabs https://gissilabs.github.io/charts/
helm install my-vaultwarden gissilabs/vaultwarden --version 1.2.5
# Output YAML manifests for Vaultwarden
helm template my-vaultwarden gissilabs/vaultwarden --version 1.2.5 > ../kubernetes/vaultwarden/my-vaultwarden.yaml
# Pull values.yaml for Vaultwarden
helm show values gissilabs/vaultwarden --version 1.2.5 > ../kubernetes/vaultwarden/my-vaultwarden.values.yaml

 # --- n8n ---
mkdir -p ../kubernetes/n8n
helm install my-n8n oci://8gears.container-registry.com/library/n8n --version 1.0.10
# Output YAML manifests for n8n
helm template my-n8n oci://8gears.container-registry.com/library/n8n --version 1.0.10 > ../kubernetes/n8n/my-n8n.yaml
# Pull values.yaml for n8n
helm show values oci://8gears.container-registry.com/library/n8n --version 1.0.10 > ../kubernetes/n8n/my-n8n.values.yaml

 # --- FoundryVTT ---
mkdir -p ../kubernetes/foundryvtt
helm repo add geek-cookbook https://geek-cookbook.github.io/charts/
helm install my-foundryvtt geek-cookbook/foundryvtt --version 3.4.2
# Output YAML manifests for FoundryVTT
helm template my-foundryvtt geek-cookbook/foundryvtt --version 3.4.2 > ../kubernetes/foundryvtt/my-foundryvtt.yaml
# Pull values.yaml for FoundryVTT
helm show values geek-cookbook/foundryvtt --version 3.4.2 > ../kubernetes/foundryvtt/my-foundryvtt.values.yaml

 # --- Keycloak ---
mkdir -p ../kubernetes/keycloak
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-keycloak bitnami/keycloak --version 24.8.1
# Output YAML manifests for Keycloak
helm template my-keycloak bitnami/keycloak --version 24.8.1 > ../kubernetes/keycloak/my-keycloak.yaml
# Pull values.yaml for Keycloak
helm show values bitnami/keycloak --version 24.8.1 > ../kubernetes/keycloak/my-keycloak.values.yaml

helm repo add cert-manager https://charts.jetstack.io
helm install my-cert-manager cert-manager/cert-manager --version 1.18.2

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install my-kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 75.16.1