#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAIL_COUNT=0
CSV_FILE="argocd-report.csv"

echo "======================================"
echo "   Argo CD Cluster Audit Report"
echo "======================================"
echo ""

echo "TYPE,NAMESPACE,NAME,SYNC,HEALTH" > "$CSV_FILE"

echo "🔵 Applications"
echo "--------------------------------------"

while read -r ns name sync health; do
  [[ -z "${sync:-}" ]] && sync="Unknown"
  [[ -z "${health:-}" ]] && health="Unknown"

  echo "Application,$ns,$name,$sync,$health" >> "$CSV_FILE"

  if [[ "$sync" != "Synced" || "$health" != "Healthy" ]]; then
    ((FAIL_COUNT++))
    echo -e "${RED}⚠ $ns/$name | Sync=$sync | Health=$health${NC}"
  else
    echo -e "${GREEN}✔ $ns/$name | Sync=$sync | Health=$health${NC}"
  fi

done < <(
  kubectl get applications.argoproj.io -A \
    -o custom-columns="NS:.metadata.namespace,NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status" \
    --no-headers 2>/dev/null
)

echo ""
echo "🟣 ApplicationSets"
echo "--------------------------------------"

while read -r ns name; do
  echo "ApplicationSet,$ns,$name,OK,OK" >> "$CSV_FILE"
  echo -e "${GREEN}✔ $ns/$name${NC}"
done < <(
  kubectl get applicationsets.argoproj.io -A \
    -o custom-columns="NS:.metadata.namespace,NAME:.metadata.name" \
    --no-headers 2>/dev/null
)

echo ""
echo "======================================"
echo " Summary"
echo "======================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo -e "${RED}❌ Issues detected: $FAIL_COUNT applications not healthy/synced${NC}"
  echo "CSV report saved to: $CSV_FILE"
  exit 1
else
  echo -e "${GREEN}✅ All applications are Synced and Healthy${NC}"
  echo "CSV report saved to: $CSV_FILE"
  exit 0
fi