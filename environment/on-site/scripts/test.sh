#!/usr/bin/env bash
# =============================================================================
# cluster-assess.sh — Kubernetes Homelab Cluster Assessment
# Covers: nodes, namespaces, ArgoCD app sync/health, Gateway API, pod health,
#         resource usage, recent events, and reachability checks.
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
section()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; \
             echo -e "${BOLD}${CYAN}  $*${RESET}"; \
             echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; }
ok()       { echo -e "  ${GREEN}✔${RESET}  $*"; }
warn()     { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
fail()     { echo -e "  ${RED}✘${RESET}  $*"; }
info()     { echo -e "     $*"; }

ISSUES=0
note_issue() { ISSUES=$(( ISSUES + 1 )); }

# ── 0. Prerequisites ──────────────────────────────────────────────────────────
section "Prerequisites"

for cmd in kubectl argocd curl jq; do
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd found ($(command -v "$cmd"))"
  else
    warn "$cmd not found — some checks will be skipped"
  fi
done

# ── 1. Cluster connectivity ───────────────────────────────────────────────────
section "Cluster Connectivity"

if kubectl cluster-info &>/dev/null 2>&1; then
  ok "kubectl can reach the cluster"
  kubectl cluster-info 2>/dev/null | sed 's/^/     /'
else
  fail "kubectl cannot reach the cluster"
  note_issue
  echo -e "\n${RED}Cannot continue without cluster access.${RESET}"
  exit 1
fi

# ── 2. Nodes ──────────────────────────────────────────────────────────────────
section "Nodes"

NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
info "Total nodes: ${NODE_COUNT}"

while IFS= read -r line; do
  NAME=$(echo "$line" | awk '{print $1}')
  STATUS=$(echo "$line" | awk '{print $2}')
  ROLES=$(echo "$line" | awk '{print $3}')
  VERSION=$(echo "$line" | awk '{print $5}')
  if [[ "$STATUS" == "Ready" ]]; then
    ok "Node ${NAME} [${ROLES}] — ${STATUS} (${VERSION})"
  else
    fail "Node ${NAME} [${ROLES}] — ${STATUS} (${VERSION})"
    note_issue
  fi
done < <(kubectl get nodes --no-headers 2>/dev/null)

# ── 3. Namespaces ─────────────────────────────────────────────────────────────
section "Namespaces"

kubectl get namespaces --no-headers 2>/dev/null | awk '{print "     "$1" — "$2}' || true

EXPECTED_NS=(argocd traefik cert-manager homepage keycloak n8n neo4j)
for ns in "${EXPECTED_NS[@]}"; do
  if kubectl get namespace "$ns" &>/dev/null 2>&1; then
    ok "Namespace '${ns}' exists"
  else
    fail "Namespace '${ns}' is MISSING"
    note_issue
  fi
done

# ── 4. Pod health (all namespaces) ────────────────────────────────────────────
section "Pod Health (all namespaces)"

TOTAL_PODS=0; NOT_RUNNING=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  NS=$(echo "$line"    | awk '{print $1}')
  NAME=$(echo "$line"  | awk '{print $2}')
  READY=$(echo "$line" | awk '{print $3}')
  STATUS=$(echo "$line"| awk '{print $4}')
  RESTARTS=$(echo "$line" | awk '{print $5}')

  TOTAL_PODS=$(( TOTAL_PODS + 1 ))

  if [[ "$STATUS" == "Running" || "$STATUS" == "Completed" || "$STATUS" == "Succeeded" ]]; then
    # Flag high restarts even if running
    if [[ "$RESTARTS" =~ ^[0-9]+$ ]] && (( RESTARTS >= 5 )); then
      warn "${NS}/${NAME} — ${STATUS} (ready: ${READY}) ⚠ ${RESTARTS} restarts"
      note_issue
    else
      ok "${NS}/${NAME} — ${STATUS} (ready: ${READY})"
    fi
  else
    fail "${NS}/${NAME} — ${STATUS} (ready: ${READY}, restarts: ${RESTARTS})"
    note_issue
    NOT_RUNNING=$(( NOT_RUNNING + 1 ))
  fi
done < <(kubectl get pods -A --no-headers 2>/dev/null)

info "Total pods: ${TOTAL_PODS} | Unhealthy: ${NOT_RUNNING}"

# ── 5. ArgoCD application sync & health ───────────────────────────────────────
section "ArgoCD Applications"

ARGOCD_NS="argocd"
APPS=(argocd traefik cert-manager homepage keycloak n8n neo4j)

if ! kubectl get deployment argocd-server -n "$ARGOCD_NS" &>/dev/null 2>&1; then
  warn "ArgoCD server deployment not found in namespace '${ARGOCD_NS}' — skipping app checks"
else
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    APP=$(echo "$line"    | awk '{print $1}')
    SYNC=$(echo "$line"   | awk '{print $2}')
    HEALTH=$(echo "$line" | awk '{print $3}')

    if [[ "$SYNC" == "Synced" && "$HEALTH" == "Healthy" ]]; then
      ok "${APP} — Sync: ${SYNC} | Health: ${HEALTH}"
    elif [[ "$SYNC" == "Synced" && "$HEALTH" != "Healthy" ]]; then
      warn "${APP} — Sync: ${SYNC} | Health: ${HEALTH}"
      note_issue
    else
      fail "${APP} — Sync: ${SYNC} | Health: ${HEALTH}"
      note_issue
    fi
  done < <(kubectl get applications -n "$ARGOCD_NS" \
      -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' \
      --no-headers 2>/dev/null || true)

  # Check ArgoCD repo-server for --enable-helm flag
  REPO_ARGS=$(kubectl get deployment argocd-repo-server -n "$ARGOCD_NS" \
    -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null || echo "")
  if echo "$REPO_ARGS" | grep -q "enable-helm"; then
    ok "argocd-repo-server has --enable-helm"
  else
    warn "argocd-repo-server may be missing --enable-helm (Sync: Unknown risk)"
    note_issue
  fi

  # Check server.insecure param
  INSECURE_VAL=$(kubectl get configmap argocd-cmd-params-cm -n "$ARGOCD_NS" \
    -o jsonpath='{.data.server\.insecure}' 2>/dev/null || echo "")
  if [[ "$INSECURE_VAL" == "true" ]]; then
    ok "argocd-cmd-params-cm server.insecure = \"true\""
  else
    warn "argocd-cmd-params-cm server.insecure = \"${INSECURE_VAL}\" (expected string \"true\")"
    note_issue
  fi
fi

# ── 6. Gateway API resources ──────────────────────────────────────────────────
section "Gateway API"

# GatewayClass
GC_COUNT=$(kubectl get gatewayclasses --no-headers 2>/dev/null | wc -l | tr -d ' ')
if (( GC_COUNT > 0 )); then
  ok "GatewayClasses found: ${GC_COUNT}"
  kubectl get gatewayclasses --no-headers 2>/dev/null | while read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    CTRL=$(echo "$line" | awk '{print $2}')
    info "  GatewayClass: ${NAME} (controller: ${CTRL})"
  done
else
  fail "No GatewayClasses found"
  note_issue
fi

# Gateway
GW_LINES=$(kubectl get gateways -A --no-headers 2>/dev/null || true)
if [[ -n "$GW_LINES" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    NS=$(echo "$line"     | awk '{print $1}')
    NAME=$(echo "$line"   | awk '{print $2}')
    CLASS=$(echo "$line"  | awk '{print $3}')
    # "Programmed" condition surfaced in READY column on newer CRD versions
    READY=$(echo "$line"  | awk '{print $NF}')
    ok "Gateway ${NS}/${NAME} (class: ${CLASS})"
    info "     Status field: ${READY}"
  done <<< "$GW_LINES"
else
  fail "No Gateway resources found"
  note_issue
fi

# HTTPRoutes
HR_COUNT=$(kubectl get httproutes -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if (( HR_COUNT > 0 )); then
  ok "HTTPRoutes found: ${HR_COUNT}"
  kubectl get httproutes -A --no-headers 2>/dev/null | while read -r line; do
    NS=$(echo "$line"   | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    info "  HTTPRoute: ${NS}/${NAME}"
  done
else
  warn "No HTTPRoute resources found"
  note_issue
fi

# ── 7. Traefik ────────────────────────────────────────────────────────────────
section "Traefik"

TRAEFIK_NS="traefik"
TRAEFIK_DEPLOY=$(kubectl get deployment -n "$TRAEFIK_NS" --no-headers 2>/dev/null | head -1 || true)
if [[ -n "$TRAEFIK_DEPLOY" ]]; then
  DESIRED=$(echo "$TRAEFIK_DEPLOY" | awk '{print $2}' | cut -d/ -f2)
  READY=$(echo "$TRAEFIK_DEPLOY"   | awk '{print $2}' | cut -d/ -f1)
  NAME=$(echo "$TRAEFIK_DEPLOY"    | awk '{print $1}')
  if [[ "$READY" == "$DESIRED" ]]; then
    ok "Traefik deployment '${NAME}' — ${READY}/${DESIRED} ready"
  else
    fail "Traefik deployment '${NAME}' — ${READY}/${DESIRED} ready"
    note_issue
  fi

  # Check gateway.enabled is not creating a conflicting auto-gateway
  GW_IN_TRAEFIK=$(kubectl get gateway -n "$TRAEFIK_NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if (( GW_IN_TRAEFIK == 0 )); then
    ok "No auto-created Gateway in traefik namespace (gateway.enabled=false confirmed)"
  else
    warn "${GW_IN_TRAEFIK} Gateway(s) in traefik namespace — verify these aren't conflicting"
  fi
else
  fail "No Traefik deployment found in namespace '${TRAEFIK_NS}'"
  note_issue
fi

# NodePort services (host port mapping 30080/30443)
NP_SVC=$(kubectl get svc -A --no-headers 2>/dev/null | grep -E "30080|30443" || true)
if [[ -n "$NP_SVC" ]]; then
  ok "NodePort services exposing 30080/30443 found:"
  echo "$NP_SVC" | while read -r line; do
    NS=$(echo "$line"   | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    PORTS=$(echo "$line"| awk '{print $6}')
    info "  ${NS}/${NAME} — ${PORTS}"
  done
else
  warn "No NodePort services found on 30080/30443 — host port mapping may not be active"
  note_issue
fi

# ── 8. cert-manager ───────────────────────────────────────────────────────────
section "cert-manager"

CM_NS="cert-manager"
CM_PODS=$(kubectl get pods -n "$CM_NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if (( CM_PODS > 0 )); then
  ok "cert-manager pods: ${CM_PODS}"
  CERT_COUNT=$(kubectl get certificates -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
  CR_COUNT=$(kubectl get certificaterequests -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
  info "  Certificates: ${CERT_COUNT} | CertificateRequests: ${CR_COUNT}"
else
  warn "No cert-manager pods found"
  note_issue
fi

# ── 9. HTTP reachability ───────────────────────────────────────────────────────
section "HTTP Reachability (localhost)"

check_url() {
  local label="$1" url="$2"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [[ "$http_code" =~ ^[23] ]]; then
    ok "${label} → ${url} [HTTP ${http_code}]"
  elif [[ "$http_code" == "000" ]]; then
    fail "${label} → ${url} [no response / timeout]"
    note_issue
  else
    warn "${label} → ${url} [HTTP ${http_code}]"
    note_issue
  fi
}

check_url "ArgoCD UI"  "http://localhost/argocd"
check_url "homepage"   "http://localhost"
check_url "Traefik API" "http://localhost:9000/api/overview"  # Traefik dashboard API (if exposed)

# ── 10. Recent warning events ─────────────────────────────────────────────────
section "Recent Warning Events (last 15 minutes)"

WARN_EVENTS=$(kubectl get events -A --field-selector type=Warning \
  --sort-by='.lastTimestamp' --no-headers 2>/dev/null | tail -20 || true)

if [[ -z "$WARN_EVENTS" ]]; then
  ok "No Warning events found"
else
  warn "Warning events detected:"
  echo "$WARN_EVENTS" | while IFS= read -r line; do
    info "  $line"
  done
  note_issue
fi

# ── 11. Resource usage (if metrics-server available) ──────────────────────────
section "Resource Usage"

if kubectl top nodes &>/dev/null 2>&1; then
  ok "metrics-server available"
  echo ""
  kubectl top nodes 2>/dev/null | sed 's/^/     /'
  echo ""
  kubectl top pods -A 2>/dev/null | sort -k4 -rh | head -15 | sed 's/^/     /'
else
  info "metrics-server not available — skipping resource usage (normal for Kind without it)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
section "Assessment Summary"

if (( ISSUES == 0 )); then
  echo -e "  ${GREEN}${BOLD}✔  All checks passed — cluster looks healthy!${RESET}"
else
  echo -e "  ${YELLOW}${BOLD}⚠  ${ISSUES} issue(s) flagged above — review the ✘/⚠ items.${RESET}"
fi

echo ""