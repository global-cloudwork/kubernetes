#!/bin/bash
set -euo pipefail

apt update -y
apt upgrade -y

# Prepare a directory to host the dynamic bootstrap script
BOOTSTRAP_DIR="/home/ubuntu/bootstrap"
mkdir -p "$BOOTSTRAP_DIR"

# Create a bootstrap script that will fetch and execute the latest init.sh from GitHub
BOOTSTRAP_PATH="$BOOTSTRAP_DIR/bootstrap"
cat > "$BOOTSTRAP_PATH" <<'EOS'
#!/bin/bash
set -euo pipefail
# Fetch and execute the latest init script from GitHub (updated path)
cURL -fsSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/scripts/environments/cloud-proxy/init-cloud-proxy.sh | bash
EOS

chmod 755 "$BOOTSTRAP_PATH"