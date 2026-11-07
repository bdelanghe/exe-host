#!/bin/sh
# facto-db: Tailscale Service svc:facto-db (TCP 5432) -> 127.0.0.1:5432 (pgbouncer -> Neon). Only once configured.
[ -f /etc/exe-host/facto-db/upstream.ini ] || exit 0
tailscale serve --service=svc:facto-db --tcp=5432 tcp://127.0.0.1:5432
