# 🔧 NGINX Monitoring Setup with Prometheus and Grafana

This project provides an automated script (`setup_full_nginx_monitoring.sh`) to monitor an NGINX web server using Prometheus and Grafana. It installs and configures all required components on an Ubuntu Linux system.

---

## 📜 Script Summary: `setup_full_nginx_monitoring.sh`

The script automates the following:

### ✅ Step 1: Install and Configure NGINX
- Installs NGINX via `apt`.
- Edits the default config to enable `/status` using the `stub_status` module for internal stats.
- Reloads NGINX to apply changes.

### ✅ Step 2: Install Node Exporter
- Downloads and installs Node Exporter v1.7.0.
- Configures it as a systemd service with support for custom metrics via `textfile_collector`.
- Starts Node Exporter to listen on `http://<your-ip>:9100`.

### ✅ Step 3: NGINX Health Monitoring Script
- Creates `/usr/local/bin/nginx_health.sh` which:
  - Checks if NGINX is running.
  - Restarts NGINX if it's down and logs the event.
  - Outputs custom metrics:
    - `nginx_custom_up` (1 = up, 0 = down)
    - `custom_uptime_seconds` (server uptime)
- Creates a cron job to run this script every minute (`/etc/cron.d/nginx_monitor`).

### ✅ Step 4: Install and Run Prometheus
- Downloads Prometheus v2.52.0.
- Configures it to scrape:
  - Node Exporter (including custom metrics)
- Runs Prometheus in the background on `http://<your-ip>:9090`.

### ✅ Step 5: Install and Start Grafana
- Adds the Grafana APT repo and installs Grafana.
- Configures Grafana to listen on all interfaces.
- Starts the Grafana service on `http://<your-ip>:3000`.

---

## ⚠️ Port Access Requirements

Ensure that the following ports are **open** on your firewall or cloud security group to allow external access:

| Service       | Port  | Description                 |
|---------------|-------|-----------------------------|
| NGINX         | 80    | Web server                  |
| Node Exporter | 9100  | Metrics exporter            |
| Prometheus    | 9090  | Metrics collection & UI     |
| Grafana       | 3000  | Dashboard visualization     |

### 🔓 Open Ports on Ubuntu UFW (if enabled)

```bash
sudo ufw allow 80    # NGINX
sudo ufw allow 9100  # Node Exporter
sudo ufw allow 9090  # Prometheus
sudo ufw allow 3000  # Grafana


---

## ✋ Manual Steps (Post-Script)

After running the script, complete the following manually:

### 1. 📊 Configure Grafana Dashboard
- Open: `http://<your-ip>:3000`
- Default login: `admin / admin`
- Add **Prometheus** as a data source:
  - URL: `http://localhost:9090`
- Import or create dashboards that show:
  - `nginx_custom_up` (as a stat panel)
  - `custom_uptime_seconds` (as a graph)

### 2. 🔒 Optional: Configure Firewall
If you want to access ports remotely, allow them through the firewall:

```bash
sudo ufw allow 80    # NGINX
sudo ufw allow 9100  # Node Exporter
sudo ufw allow 9090  # Prometheus
sudo ufw allow 3000  # Grafana
