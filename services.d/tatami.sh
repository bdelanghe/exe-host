#!/bin/sh
# tatami: Tailscale Service svc:tatami (HTTPS 443) -> trip-projector on loopback.
# Origin https://tatami.tail556f5b.ts.net must never change (the PWA stores data per origin).
# Only once the projector is installed. Port is set in /etc/exe-host/tatami/port (default 8891).
[ -f /etc/exe-host/tatami/enabled ] || exit 0
port=8891
[ -f /etc/exe-host/tatami/port ] && port=$(cat /etc/exe-host/tatami/port)
tailscale serve --service=svc:tatami --https=443 "http://127.0.0.1:$port"
