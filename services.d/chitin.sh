#!/bin/sh
# chitin: Tailscale Service svc:chitin (HTTPS 443) -> chitin's Caddy on loopback 127.0.0.1:7490
# (router, notify-sink and chitin-approve, each with a /healthz; chitin/compose.yaml).
# Only once chitin is installed. Touches svc:chitin only: never `tailscale serve reset`.
[ -f /etc/exe-host/chitin/enabled ] || exit 0
tailscale serve --service=svc:chitin --https=443 http://127.0.0.1:7490
