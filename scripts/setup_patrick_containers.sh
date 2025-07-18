#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Running One-Time Setup for Patrick's Containers ---"

# 1. Create ~/bin directory for scripts
echo "Creating ~/bin directory..."
mkdir -p ~/bin
echo "Done."

# 2. Copy docker-static-ip to ~/bin/ and setting permissions...
echo "Copying docker-static-ip to ~/bin/ and setting permissions..."
cp scripts/docker-static-ip ~/bin/
chmod +x ~/bin/docker-static-ip
echo "Done."

# 3. Create the custom Docker network (docker26)
echo "Creating Docker network 'docker26' (if it doesn't exist)..."
if ! docker network ls | grep -q "docker26"; then
  sudo docker network create \
    -d bridge -o "com.docker.network.bridge.name=docker26" \
    --subnet=172.26.0.0/16 docker26
  echo "Network 'docker26' created."
else
  echo "Network 'docker26' already exists."
fi
echo "Done."

# 4. Add HAProxy hostname to your MacBook's /etc/hosts
echo "Adding haproxy.cadc.dao.nrc.ca to /etc/hosts (requires sudo)..."
if ! grep -q "haproxy.cadc.dao.nrc.ca" /etc/hosts; then
  echo "127.0.0.1 haproxy.cadc.dao.nrc.ca" | sudo tee -a /etc/hosts > /dev/null
  echo "/etc/hosts updated."
else
  echo "/etc/hosts already contains haproxy.cadc.dao.nrc.ca."
fi
echo "Done."

# 5. Generate a dummy SSL certificate for HAProxy
echo "Generating dummy SSL certificate for HAProxy..."
mkdir -p infra/haproxy/config
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout infra/haproxy/config/server-cert.pem \
  -out infra/haproxy/config/server-cert.pem \
  -subj "/CN=haproxy.cadc.dao.nrc.ca"
echo "Dummy SSL certificate created at infra/haproxy/config/server-cert.pem."
echo "Done."

# REMOVED: Creation of /data/local directories, now handled by individual doit scripts relative to repo.

echo "--- Setup Complete! ---"
echo "You can now proceed to deploy and manage services using manage_patrick_containers.sh."

