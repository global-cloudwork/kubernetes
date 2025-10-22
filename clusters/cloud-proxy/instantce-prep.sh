#!/bin/bash
# Runs as root on first boot

# 1. Update system packages
apt update -y

# 2. Install git
apt install git -y

# 3. Clone a public, non-sensitive repository into a temporary location
# Using a generic path like /tmp for the clone operation
git clone https://github.com/a-public-user/a-safe-repo.git /tmp/safe-repo

# 4. Create the target user directory if it doesn't exist (e.g., /home/ubuntu)
# NOTE: This ensures the target folder exists and has correct ownership.
if id -u ubuntu &>/dev/null; then
  # Copy a specific file into the ubuntu user's home directory
  cp /tmp/safe-repo/config-file.txt /home/ubuntu/
  # Set ownership to the ubuntu user so they can read/write the file
  chown ubuntu:ubuntu /home/ubuntu/config-file.txt
fi

# 5. Clean up the temporary repository clone
rm -rf /tmp/safe-repo