#!/bin/sh

set -e

# Install openssl
apk add --no-cache openssl

# Create directories
mkdir -p /certs/haproxy
mkdir -p /certs/src-cavern

# Generate the private key and the certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /certs/haproxy/server-cert.pem.key \
  -out /certs/haproxy/server-cert-only.pem \
  -subj "/CN=haproxy"

# Combine the key and certificate into a single file for HAProxy
cat /certs/haproxy/server-cert.pem.key /certs/haproxy/server-cert-only.pem > /certs/haproxy/server-cert.pem

# Extract the public certificate for Java compatibility
openssl x509 -in /certs/haproxy/server-cert-only.pem -out /certs/src-cavern/haproxy-pub.pem

echo "[cert-gen] All certificates generated successfully."