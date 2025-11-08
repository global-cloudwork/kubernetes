#!/bin/bash
set -euo pipefail

apt update -y
apt upgrade -y

# Prepare a directory to host the dynamic bootstrap script
BOOTSTRAP_DIR="/home/ubuntu/bootstrap"
mkdir -p "$BOOTSTRAP_DIR"

# Create a bootstrap script that will fetch and execute the latest init.sh from GitHub
BOOTSTRAP_PATH="$BOOTSTRAP_DIR/boostrap"
cat > "$BOOTSTRAP_PATH" <<'EOS'
#!/bin/bash
set -euo pipefail
# Fetch and execute the latest init script from GitHub
curl -fsSL https://raw.githubusercontent.com/global-cloudwork/kubernetes/main/clusters/cloud-proxy/init.sh | bash
EOS

chmod 755 "$BOOTSTRAP_PATH"