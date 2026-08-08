#!/usr/bin/env bash
# ============================================================
# Haalkhata production server bootstrap - run as root
# Ubuntu 24.04, 2 GiB RAM, 1 vCPU
# ============================================================
set -euo pipefail

ADMIN_KEY="/root/deploy_key.pub"
DEPLOY_USER="deploy"
SSH_PORT=22022

echo "==> Updating system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release \
    ufw fail2ban unattended-upgrades apt-listchanges rsync htop

echo "==> Configuring unattended-upgrades (auto security patches)"
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true

echo "==> Setting timezone to Asia/Dhaka"
timedatectl set-timezone Asia/Dhaka || true

echo "==> Creating 2 GiB swap (2 GiB RAM server)"
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl -w vm.swappiness=10 >/dev/null
    grep -q 'vm.swappiness' /etc/sysctl.conf || echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

echo "==> Creating deploy user"
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo "$DEPLOY_USER"
    echo "$DEPLOY_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$DEPLOY_USER
    chmod 440 /etc/sudoers.d/$DEPLOY_USER
fi
mkdir -p /home/$DEPLOY_USER/.ssh
chmod 700 /home/$DEPLOY_USER/.ssh
if [ -f "$ADMIN_KEY" ]; then
    cp "$ADMIN_KEY" /home/$DEPLOY_USER/.ssh/authorized_keys
    chown -R $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh
    chmod 600 /home/$DEPLOY_USER/.ssh/authorized_keys
fi

echo "==> Enabling key-only SSH (root login by key, password auth off)"
if [ -f "$ADMIN_KEY" ]; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    cp "$ADMIN_KEY" /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config || echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
    grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin prohibit-password' >> /etc/ssh/sshd_config
    systemctl reload ssh
else
    echo "WARNING: $ADMIN_KEY not found - password SSH auth left unchanged!"
fi

echo "==> Configuring fail2ban for sshd on port $SSH_PORT"
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
EOF
systemctl enable --now fail2ban

echo "==> Configuring UFW firewall"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow $SSH_PORT/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS auth'
ufw allow 8443/tcp comment 'HTTPS haalkhata'
ufw --force enable

echo "==> Installing Docker Engine + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "==> Tuning Docker daemon (log rotation, live-restore)"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true,
  "default-ulimits": {
    "nofile": { "Name": "nofile", "Hard": 65535, "Soft": 65535 }
  }
}
EOF
systemctl enable docker >/dev/null 2>&1 || true
systemctl restart docker
usermod -aG docker "$DEPLOY_USER" || true

echo "==> Creating app directory"
mkdir -p /opt/haalkhata/backups
chown -R $DEPLOY_USER:$DEPLOY_USER /opt/haalkhata

echo "==> BOOTSTRAP COMPLETE =="
echo "SSH: ssh -p $SSH_PORT $DEPLOY_USER@104.207.92.108 (key only)"
