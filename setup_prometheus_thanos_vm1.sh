#!/bin/bash

# Variables
PROMETHEUS_VERSION="2.52.0"
THANOS_VERSION="0.35.0"
INSTALL_DIR="/opt/prometheus"
CONFIG_DIR="/etc/prometheus"
DATA_DIR="/var/lib/prometheus"
CERT_DIR="/var/lib/thanos"
OBJSTORE_CONFIG="$CONFIG_DIR/objstore.yml"

# Create necessary directories
sudo mkdir -p $INSTALL_DIR $CONFIG_DIR $DATA_DIR $CERT_DIR /var/lib/thanos

# Create a Prometheus user
sudo useradd --no-create-home --shell /bin/false prometheus

# Download Prometheus
curl -LO https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
tar xvf prometheus-$PROMETHEUS_VERSION.linux-amd64.tar.gz
sudo mv prometheus-$PROMETHEUS_VERSION.linux-amd64/* $INSTALL_DIR

# Download Thanos
curl -LO https://github.com/thanos-io/thanos/releases/download/$THANOS_VERSION/thanos-$THANOS_VERSION.linux-amd64.tar.gz
tar xvf thanos-$THANOS_VERSION.linux-amd64.tar.gz
sudo mv thanos-$THANOS_VERSION.linux-amd64/* $INSTALL_DIR

# Make Thanos executable
sudo chmod +x $INSTALL_DIR/thanos

# Create Prometheus configuration file
cat <<EOF | sudo tee $CONFIG_DIR/prometheus.yml
global:
  scrape_interval: 15s
  external_labels:
    monitor: 'prometheus-vm1'
    cluster: 'prod'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090', '<PROMETHEUS2_VM_IP>:9090']
EOF

# Create systemd service file for Prometheus
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=$INSTALL_DIR/prometheus --config.file=$CONFIG_DIR/prometheus.yml --storage.tsdb.path=$DATA_DIR --storage.tsdb.min-block-duration=2h --storage.tsdb.max-block-duration=2h --storage.tsdb.retention.time=1d --storage.tsdb.allow-overlapping-blocks

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service file for Thanos Sidecar
cat <<EOF | sudo tee /etc/systemd/system/thanos-sidecar.service
[Unit]
Description=Thanos Sidecar
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=$INSTALL_DIR/thanos sidecar --http-address=0.0.0.0:10902 --grpc-address=0.0.0.0:10901 --prometheus.url=http://localhost:9090 --tsdb.path=$DATA_DIR --objstore.config-file=$OBJSTORE_CONFIG --grpc-server-tls-cert=$CERT_DIR/server.crt --grpc-server-tls-key=$CERT_DIR/server.key --grpc-server-tls-client-ca=$CERT_DIR/ca.crt

[Install]
WantedBy=multi-user.target
EOF

# Create objstore.yml for local filesystem
cat <<EOF | sudo tee $OBJSTORE_CONFIG
type: FILESYSTEM
config:
  directory: /var/lib/thanos
EOF

# Create the Thanos storage directory
sudo mkdir -p /var/lib/thanos

# Create a valid thanos.shipper.json file if it does not exist
if [ ! -f "$DATA_DIR/thanos.shipper.json" ]; then
  echo '{"version": 1}' | sudo tee $DATA_DIR/thanos.shipper.json > /dev/null
fi
sudo chown prometheus:prometheus $DATA_DIR/thanos.shipper.json

# Ensure all directories and files have the correct permissions
sudo chown -R prometheus:prometheus $INSTALL_DIR $CONFIG_DIR $DATA_DIR $CERT_DIR /var/lib/thanos

# Reload systemd and start services
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
sudo systemctl start thanos-sidecar
sudo systemctl enable thanos-sidecar
