#!/bin/bash

# Variables
THANOS_VERSION="0.35.0"
INSTALL_DIR="/opt/thanos"
CONFIG_DIR="/etc/thanos"
CERT_DIR="/var/lib/thanos"
OBJSTORE_CONFIG="$CONFIG_DIR/objstore.yml"
NGINX_VERSION="1.24.0" # specify the version of NGINX you want to install
NGINX_INSTALL_DIR="/opt/nginx"
NGINX_CONFIG="/etc/nginx/nginx.conf"
HTPASSWD_FILE="/etc/nginx/.htpasswd"

# Create necessary directories
sudo mkdir -p $INSTALL_DIR $CONFIG_DIR $CERT_DIR $NGINX_INSTALL_DIR

# Download Thanos
curl -LO https://github.com/thanos-io/thanos/releases/download/v$THANOS_VERSION/thanos-$THANOS_VERSION.linux-amd64.tar.gz
tar xvf thanos-$THANOS_VERSION.linux-amd64.tar.gz
sudo mv thanos-$THANOS_VERSION.linux-amd64/* $INSTALL_DIR

# Download and install NGINX
curl -LO http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
tar xvf nginx-$NGINX_VERSION.tar.gz
cd nginx-$NGINX_VERSION
./configure --prefix=$NGINX_INSTALL_DIR
make
sudo make install

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
ExecStart=$INSTALL_DIR/thanos query --http-address=0.0.0.0:10902 --store=172.18.115.6:10901 --store=172.18.115.7:10903 --store=thanos-store:10904 --grpc-client-tls-cert=$CERT_DIR/server.crt --grpc-client-tls-key=$CERT_DIR/server.key --grpc-client-tls-ca=$CERT_DIR/ca.crt

[Install]
WantedBy=multi-user.target
EOF

# Create NGINX configuration directory and file
sudo mkdir -p /etc/nginx
cat <<EOF | sudo tee $NGINX_CONFIG
events {}

http {
  server {
    listen 443 ssl;
    server_name _;

    ssl_certificate $CERT_DIR/server.crt;
    ssl_certificate_key $CERT_DIR/server.key;
    ssl_client_certificate $CERT_DIR/ca.crt;
    ssl_verify_client on;

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
sudo yum install -y httpd-tools
sudo htpasswd -bc $HTPASSWD_FILE grafana TPLkdZ4290BeQ

# Create objstore.yml for local filesystem
cat <<EOF | sudo tee $OBJSTORE_CONFIG
type: FILESYSTEM
config:
  directory: /var/lib/thanos
EOF

# Create the Thanos storage directory
sudo mkdir -p /var/lib/thanos

# Copy TLS certificates to the appropriate directories, but only if source and destination are different
[ "$CERT_DIR/server.crt" != "$CERT_DIR/server.crt" ] && sudo cp $CERT_DIR/server.crt $CERT_DIR/server.crt
[ "$CERT_DIR/server.key" != "$CERT_DIR/server.key" ] && sudo cp $CERT_DIR/server.key $CERT_DIR/server.key
[ "$CERT_DIR/ca.crt" != "$CERT_DIR/ca.crt" ] && sudo cp $CERT_DIR/ca.crt $CERT_DIR/ca.crt

# Set permissions
sudo chown -R prometheus:prometheus $INSTALL_DIR $CONFIG_DIR $CERT_DIR /var/lib/thanos

# Reload systemd and start services
sudo systemctl daemon-reload
sudo systemctl start thanos-store
sudo systemctl enable thanos-store
sudo systemctl start thanos-querier
sudo systemctl enable thanos-querier

# Create systemd service file for NGINX
cat <<EOF | sudo tee /etc/systemd/system/nginx.service
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
ExecStartPre=$NGINX_INSTALL_DIR/sbin/nginx -t
ExecStart=$NGINX_INSTALL_DIR/sbin/nginx
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start nginx
sudo systemctl enable nginx
