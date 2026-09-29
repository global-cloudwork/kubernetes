#!/usr/bin/env bash
source .env

phases=(
  "https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.crds.yaml https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/experimental-install.yaml"
  "https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/kubernetes/bootstrap/namespace.yaml https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/kubernetes/argocd/app-project.yaml https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/kubernetes/argocd/argocd-commit-status.yaml"
  "https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/kubernetes/argocd/application-set.yaml"
)

curl -fsSL https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64 -o /usr/local/bin/kind && chmod 0755 /usr/local/bin/kind
curl -fsSL "https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/bash/omen/kind-config.yaml" | kind create cluster --config -

kubectl apply --server-side --force-conflicts -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: global-cloudwork-kubernetes
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/global-cloudwork/kubernetes
  githubAppID: ${GITHUB_APP_ID_FILE}
  githubAppInstallationID: ${GITHUB_APP_INSTALLATION_ID_FILE}
  githubAppPrivateKey: |
$(printf '%s\n' "${GITHUB_APP_PRIVATE_KEY_FILE}" | sed 's/^/    /')
EOF

for phase in "${phases[@]}"; do
  for url in ${phase}; do
    curl -fsSL "${url}" | kubectl apply --server-side --force-conflicts -f -
  done
done
