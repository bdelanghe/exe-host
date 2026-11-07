#!/bin/sh
# Idempotent. Installs docker, tailscale, restic; starts compose services; installs the backup and tailnet timers.
# Run by setup.sh at first boot; re-run by hand (`sudo /opt/exe-host/bootstrap.sh`) after `git -C /opt/exe-host pull`.
set -eu
cd /opt/exe-host

command -v docker >/dev/null 2>&1 || { apt-get update -y && apt-get install -y docker.io docker-compose-v2 || apt-get install -y docker.io docker-compose; }
command -v restic >/dev/null 2>&1 || { apt-get update -y && apt-get install -y restic; }
command -v jq >/dev/null 2>&1 || { apt-get update -y && apt-get install -y jq curl; }
command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now docker

mkdir -p /srv/state/proof /etc/exe-host
chmod 700 /etc/exe-host
docker compose up -d --build

install -m 0755 backup.sh /usr/local/sbin/exe-host-backup
install -m 0755 join.sh /usr/local/sbin/exe-host-join
install -m 0644 systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now exe-host-backup.timer exe-host-join.timer
echo "bootstrap done: $(git rev-parse --short HEAD)"
