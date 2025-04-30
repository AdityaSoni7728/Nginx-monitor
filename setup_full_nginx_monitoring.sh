#!/bin/bash

set -e

echo "========== STEP 1: Installing and Configuring NGINX =========="
sudo apt update
sudo apt install -y nginx

sudo tee /etc/nginx/sites-available/default > /dev/null <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location /status {
        stub_status;
        allow all;
    }

    location / {
        return 200 'NGINX is running\n';
        add_header Content-Type text/plain;
    }
}
EOF

sudo nginx -t
sudo systemctl reload nginx
echo "✅ NGINX installed and /status endpoint enabled."


echo "========== STEP 2: Installing Node Exporter =========="
NODE_EXPORTER_VERSION="1.7.0"
NODE_EXPORTER_DIR="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"
NODE_EXPORTER_TAR="${NODE_EXPORTER_DIR}.tar.gz"

wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_TAR}"
tar -xvf "$NODE_EXPORTER_TAR"
sudo mv "${NODE_EXPORTER_DIR}/node_exporter" /usr/local/bin/
rm -rf "$NODE_EXPORTER_TAR" "$NODE_EXPORTER_DIR"

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter \\
  --web.listen-address="0.0.0.0:9100" \\
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo systemctl daemon-reexec
sudo systemctl enable --now node_exporter
echo "✅ Node Exporter running at http://<your-ip>:9100/metrics"


echo "========== STEP 3: Creating NGINX Health Monitor Script =========="
NGINX_MONITOR_SCRIPT="/usr/local/bin/nginx_health.sh"

sudo tee "$NGINX_MONITOR_SCRIPT" > /dev/null <<'EOF'
#!/bin/bash

METRICS_FILE="/var/lib/node_exporter/textfile_collector/nginx.prom"
LOG_FILE="/var/log/nginx_health.log"
UP=0

if systemctl is-active --quiet nginx; then
  UP=1
else
  echo "$(date): NGINX is down. Restarting..." >> "$LOG_FILE"
  systemctl restart nginx
fi

UPTIME=$(awk '{print int($1)}' /proc/uptime)

cat <<METRIC > "$METRICS_FILE"
# HELP nginx_custom_up Whether NGINX is running (1 = up, 0 = down)
# TYPE nginx_custom_up gauge
nginx_custom_up $UP

# HELP custom_uptime_seconds Uptime of the server in seconds
# TYPE custom_uptime_seconds gauge
custom_uptime_seconds $UPTIME
METRIC
EOF

EOF

sudo chmod +x "$NGINX_MONITOR_SCRIPT"
sudo mkdir -p /var/lib/node_exporter/textfile_collector

echo "🕒 Setting up cron job for health check..."
( sudo crontab -l 2>/dev/null | grep -v "$NGINX_MONITOR_SCRIPT" ; echo "* * * * * $NGINX_MONITOR_SCRIPT" ) | sudo crontab -
echo "✅ NGINX health monitoring script and cron setup complete."


echo "========== STEP 4: Installing and Running Prometheus =========="
PROM_VERSION="2.52.0"
PROM_DIR="prometheus-${PROM_VERSION}.linux-amd64"
PROM_TAR="${PROM_DIR}.tar.gz"

wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/${PROM_TAR}"
tar -xvf "$PROM_TAR"
cd "$PROM_DIR"

cat <<EOF > prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

nohup ./prometheus --config.file=prometheus.yml --web.listen-address="0.0.0.0:9090" > /dev/null 2>&1 &

cd ..
rm -f "$PROM_TAR"
echo "✅ Prometheus running at http://<your-ip>:9090"


echo "========== STEP 5: Installing Grafana =========="
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt update
sudo apt install -y grafana

sudo sed -i 's/^;http_addr = .*/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini
sudo systemctl enable --now grafana-server

echo "✅ Grafana running at http://<your-ip>:3000"


echo "🎉 ALL DONE! Services available on your server's public IP:"
echo "🔹 NGINX:          http://<your-ip>/"
echo "🔹 NGINX /status:  http://<your-ip>/status"
echo "🔹 Node Exporter:  http://<your-ip>:9100/metrics"
echo "🔹 Prometheus:     http://<your-ip>:9090"
echo "🔹 Grafana:        http://<your-ip>:3000"
