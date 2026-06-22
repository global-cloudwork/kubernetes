#!/usr/bin/env bash

# Kubernetes Cluster Health Check
# Focuses on: ArgoCD sync/health, Gateway API, local network reachability

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

section() { echo -e "\n${CYAN}==== $1 ====${NC}"; }
ok()      { echo -e "  ${GREEN}✓${NC}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail()    { echo -e "  ${RED}✗${NC}  $1"; }

# -----------------------------------------------------------------------------
# ArgoCD — Sync & Health
# -----------------------------------------------------------------------------

section "ArgoCD Applications"

if ! kubectl get applications -n argocd &>/dev/null; then
  warn "No ArgoCD applications found"
else
  while IFS= read -r line; do
    NAME=$(echo "$line"   | awk '{print $1}')
    SYNC=$(echo "$line"   | awk '{print $2}')
    HEALTH=$(echo "$line" | awk '{print $3}')

    SYNC_OK=false
    HEALTH_OK=false
    [[ "$SYNC"   == "Synced"  ]] && SYNC_OK=true
    [[ "$HEALTH" == "Healthy" ]] && HEALTH_OK=true

    if $SYNC_OK && $HEALTH_OK; then
      ok "$NAME — sync: $SYNC | health: $HEALTH"
    elif $HEALTH_OK && ! $SYNC_OK; then
      warn "$NAME — sync: $SYNC | health: $HEALTH"
    else
      fail "$NAME — sync: $SYNC | health: $HEALTH"
    fi
  done < <(kubectl get applications -n argocd --no-headers 2>/dev/null)
fi

# -----------------------------------------------------------------------------
# Gateway API — GatewayClasses
# -----------------------------------------------------------------------------

section "GatewayClasses"

GC_JSON=$(kubectl get gatewayclass -o json 2>/dev/null)
GC_COUNT=$(echo "$GC_JSON" | jq '.items | length')

if [[ "$GC_COUNT" -eq 0 ]]; then
  fail "No GatewayClasses found — Traefik may not be synced yet"
else
  echo "$GC_JSON" | jq -r '
    .items[] |
    "\(.metadata.name) controller=\(.spec.controllerName) accepted=\(.status.conditions[]? | select(.type=="Accepted") | .status)"
  ' | while IFS= read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    ACCEPTED=$(echo "$line" | grep -oP 'accepted=\K\S+')
    CTRL=$(echo "$line" | grep -oP 'controller=\K\S+')
    if [[ "$ACCEPTED" == "True" ]]; then
      ok "$NAME ($CTRL) — Accepted"
    else
      fail "$NAME ($CTRL) — NOT accepted ($ACCEPTED)"
    fi
  done
fi

# -----------------------------------------------------------------------------
# Gateway API — Gateways
# -----------------------------------------------------------------------------

section "Gateways"

GTW_JSON=$(kubectl get gateway -A -o json 2>/dev/null)
GTW_COUNT=$(echo "$GTW_JSON" | jq '.items | length')

if [[ "$GTW_COUNT" -eq 0 ]]; then
  fail "No Gateways found"
else
  echo "$GTW_JSON" | jq -r '
    .items[] |
    "\(.metadata.namespace)/\(.metadata.name) programmed=\(.status.conditions[]? | select(.type=="Programmed") | .status) addresses=\([.status.addresses[]?.value] | join(","))"
  ' | while IFS= read -r line; do
    NSNAME=$(echo "$line"     | awk '{print $1}')
    PROGRAMMED=$(echo "$line" | grep -oP 'programmed=\K\S+')
    ADDRS=$(echo "$line"      | grep -oP 'addresses=\K\S+')
    if [[ "$PROGRAMMED" == "True" ]]; then
      ok "$NSNAME — Programmed | addresses: ${ADDRS:-(none yet)}"
    else
      fail "$NSNAME — NOT programmed | addresses: ${ADDRS:-(none)}"
    fi
  done
fi

# -----------------------------------------------------------------------------
# Gateway API — HTTPRoutes
# -----------------------------------------------------------------------------

section "HTTPRoutes"

HR_JSON=$(kubectl get httproute -A -o json 2>/dev/null)
HR_COUNT=$(echo "$HR_JSON" | jq '.items | length')

if [[ "$HR_COUNT" -eq 0 ]]; then
  warn "No HTTPRoutes found"
else
  echo "$HR_JSON" | jq -r '
    .items[] |
    "\(.metadata.namespace)/\(.metadata.name) hostnames=\(.spec.hostnames // [] | join(",")) parent=\(.spec.parentRefs[0]?.name // "none")"
  ' | while IFS= read -r line; do
    NSNAME=$(echo "$line"  | awk '{print $1}')
    HOSTS=$(echo "$line"   | grep -oP 'hostnames=\K\S+')
    PARENT=$(echo "$line"  | grep -oP 'parent=\K\S+')
    echo -e "  ${CYAN}→${NC}  $NSNAME → gateway: $PARENT | hosts: ${HOSTS:-(none)}"
  done
fi

# -----------------------------------------------------------------------------
# Local Network Reachability
# -----------------------------------------------------------------------------

section "Local Network Reachability"

if ! command -v curl &>/dev/null; then
  warn "curl not installed — skipping"
else
  HOSTNAMES=$(kubectl get httproute -A -o json 2>/dev/null | \
    jq -r '.items[].spec.hostnames[]?' 2>/dev/null || true)

  if [[ -z "$HOSTNAMES" ]]; then
    warn "No hostnames found in HTTPRoutes — nothing to probe"
  else
    while IFS= read -r hostname; do
      [[ -z "$hostname" ]] && continue
      HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
        "http://$hostname" 2>/dev/null || echo "000")
      HTTPS=$(curl -ks -o /dev/null -w "%{http_code}" --connect-timeout 3 \
        "https://$hostname" 2>/dev/null || echo "000")
      if [[ "$HTTP" =~ ^(200|301|302|401|403|404)$ ]] || \
         [[ "$HTTPS" =~ ^(200|301|302|401|403|404)$ ]]; then
        ok "$hostname — HTTP: $HTTP  HTTPS: $HTTPS"
      else
        fail "$hostname — HTTP: $HTTP  HTTPS: $HTTPS (unreachable)"
      fi
    done <<< "$HOSTNAMES"
  fi
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------

section "DONE"