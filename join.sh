#!/bin/sh
# Join (or re-join) the tailnet with exe.dev's Tailscale workload identity. No stored key: the token comes from the
# integration endpoint, lives 5 minutes, and is used once. Ephemeral and pre-authorized, tag-scoped (tags from the
# integration metadata, which must be a subset of the tags picked on the Tailscale trust credential).
# Idempotent: a no-op while the node is online. Runs from exe-host-join.timer so an ephemeral node that was
# garbage-collected while offline comes back by itself.
# `join.sh publish` (bootstrap.sh): while online, re-run services.d so services added by a pull are published now;
# while offline, do nothing (the timer joins and publishes).
set -eu
WIF=${EXE_WIF_URL:-https://tailscale-wif-host.int.exe.xyz}
HOSTNAME_TS=${EXE_HOST_TSNAME:-exe-host}
SERVICES_D=${EXE_HOST_SERVICES_D:-/opt/exe-host/services.d}

if tailscale status --json 2>/dev/null | jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
  [ "${1:-}" = publish ] || exit 0
else
  [ "${1:-}" != publish ] || exit 0

  META=$(curl -fsS "$WIF/metadata")
  CLIENT_ID=$(echo "$META" | jq -er .client_id)
  TAGS=$(echo "$META" | jq -r '.tags // "tag:app-host"')
  ID_TOKEN=$(curl -fsS "$WIF/token" | jq -er .token)

  tailscale up \
    --client-id="${CLIENT_ID}?ephemeral=true&preauthorized=true" \
    --id-token="$ID_TOKEN" \
    --advertise-tags="$TAGS" \
    --hostname="$HOSTNAME_TS"
  unset ID_TOKEN
fi

# Publish each service on the tailnet (plain HTTP inside the tailnet; WireGuard already encrypts it).
for f in "$SERVICES_D"/*.sh; do [ -f "$f" ] && sh "$f"; done
