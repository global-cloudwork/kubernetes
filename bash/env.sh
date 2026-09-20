#!/usr/bin/env bash
# Shared utilities and colors for shell tooling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

source "${PROJECT_ROOT}/.env"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

GITHUB_USERNAME=$1
GITHUB_PAT_TOKEN=$2

echo_header() { echo -e "${BLUE}▶${NC} $1"; }
echo_ok() { echo -e "${GREEN}✓${NC} $1"; }
common_err() { echo -e "${RED}✗${NC} $1"; }
