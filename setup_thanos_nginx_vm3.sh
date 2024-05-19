#!/bin/bash

# Variables
THANOS_VERSION="v0.23.0"
INSTALL_DIR="/opt/thanos"
CONFIG_DIR="/etc/thanos"
CERT_DIR="/etc/thanos/certs"
OBJSTORE_CONFIG="$CONFIG_DIR/objstore.yml"
NGINX_CONFIG="/etc/nginx/nginx.conf"
HTPASSWD_FILE="/etc/nginx/.htpasswd"

# Create necessary directories
sudo mkdir -p $INSTALL_DIR $CONFIG_DIR $CERT_DIR

# Download Thanos
curl -LO https://github.com/thanos-io/thanos/releases/download/$THANOS_VERSION/thanos-$THANOS_VERSION.linux-amd64.tar.gz
tar xvf thanos-$THANOS_VERSION.linux-amd64.tar.gz
sudo mv thanos-$THANOS_VERSION.linux-amd64/* $INSTALL_DIR

# Install NGINX
sudo yum install -y epel-release
sudo yum install -y nginx httpd-tools

# Create systemd service file for Thanos Store
cat <<EOF | sudo tee /etc/systemd/system/thanos-store.service
[Unit]
Description=Thanos Store Gateway
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=$INSTALL_DIR/thanos store --objstore.config-file=$OBJSTORE_CONFIG --http-address=0.0.0.0:10905 --grpc-address=0.0.0.0:10904 --grpc-server-tls-cert=$CERT_DIR/server.crt --grpc-server-tls-key=$CERT_DIR/server.key --grpc-server-tls-client-ca=$CERT_DIR/ca.crt

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service file for Thanos Querier
cat <<EOF | sudo tee /etc/systemd/system/thanos-querier.service
[Unit]
Description=Thanos Querier
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=$INSTALL_DIR/thanos query --http-address=0.0.0.0:10902 --store=<PROMETHEUS1_VM_IP>:10901 --store=<PROMETHEUS2_VM_IP>:10903 --store=thanos-store:10904 --grpc-client-tls-cert=$CERT_DIR/server.crt --grpc-client-tls-key=$CERT_DIR/server.key --grpc-client-tls-ca=$CERT_DIR/ca.crt

[Install]
WantedBy=multi-user.target
EOF

# Create NGINX configuration file
cat <<EOF | sudo tee $NGINX_CONFIG
events {}

http {
  server {
    listen 80;

    location / {
      proxy_pass http://localhost:10902;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      auth_basic "Restricted Access";
      auth_basic_user_file $HTPASSWD_FILE;
    }
  }
}
EOF

# Set up basic authentication for NGINX
sudo htpasswd -bc $HTPASSWD_FILE <username> <password>

# Create objstore.yml for local filesystem
cat <<EOF | sudo tee $OBJSTORE_CONFIG
type: FILESYSTEM
config:
  directory: /var/lib/thanos
EOF

# Create the Thanos storage directory
sudo mkdir -p /var/lib/thanos

# Copy TLS certificates to the appropriate directories
sudo cp server.crt server.key ca.crt $CERT_DIR/

# Set permissions
sudo chown -R prometheus:prometheus $INSTALL_DIR $CONFIG_DIR $CERT_DIR /var/lib/thanos

# Reload systemd and start services
sudo systemctl daemon-reload
sudo systemctl start thanos-store
sudo systemctl enable thanos-store
sudo systemctl start thanos-querier
sudo systemctl enable thanos-querier
sudo systemctl start nginx
sudo systemctl enable nginx
