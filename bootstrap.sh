#!/bin/sh
# Idempotent. Installs docker, tailscale, restic; starts compose services; installs the backup and tailnet timers.
# Run by setup.sh at first boot; re-run by hand (`sudo /opt/exe-host/bootstrap.sh`) after `git -C /opt/exe-host pull`.
set -eu
cd /opt/exe-host

command -v docker >/dev/null 2>&1 || { apt-get update -y && apt-get install -y docker.io docker-compose-v2 || apt-get install -y docker.io docker-compose; }
command -v restic >/dev/null 2>&1 || { apt-get update -y && apt-get install -y restic; }
command -v jq >/dev/null 2>&1 || { apt-get update -y && apt-get install -y jq curl; }
command -v tailscale >/dev/null 2>&1 || curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now docker tailscaled

mkdir -p /srv/state/proof /etc/exe-host
chmod 700 /etc/exe-host

# One Unix user per service, so no process has ambient control. facto-db owns /etc/exe-host/facto-db (uid 10001).
id facto-db >/dev/null 2>&1 || useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin facto-db
id facto-pg >/dev/null 2>&1 || useradd --system --uid 10003 --no-create-home --shell /usr/sbin/nologin facto-pg
id tatami >/dev/null 2>&1 || useradd --system --uid 10002 --no-create-home --shell /usr/sbin/nologin tatami
mkdir -p /srv/state/facto-pg /etc/exe-host/facto-pg /opt/exe-host/src
chown 10003:10003 /srv/state/facto-pg
chown 10003:10003 /etc/exe-host/facto-pg
profiles=""
[ ! -f /etc/exe-host/facto-db/upstream.ini ] || profiles="$profiles,facto-db"
[ ! -f /etc/exe-host/facto-pg/password ] || profiles="$profiles,facto-pg"
[ ! -f /etc/exe-host/tatami/enabled ] || profiles="$profiles,tatami"
export COMPOSE_PROFILES="${profiles#,}"
docker compose up -d --build

install -m 0755 backup.sh /usr/local/sbin/exe-host-backup
install -m 0755 join.sh /usr/local/sbin/exe-host-join
install -m 0755 facto-db-config.sh /usr/local/sbin/exe-host-facto-db-config
install -m 0644 systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now exe-host-backup.timer exe-host-join.timer
echo "bootstrap done: $(git rev-parse --short HEAD)"
