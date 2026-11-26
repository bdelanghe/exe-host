#!/bin/sh
# `join.sh publish` (run by bootstrap.sh) re-runs services.d while the node is on the tailnet, so a service added by
# `git pull && bootstrap.sh` is published without waiting for a re-join. Plain `join.sh` (the timer) stays a no-op
# while online, and `publish` never joins. Stubs tailscale and curl on PATH; no network, no root.
# Run: sh tests/join-publish-test.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/services.d"
cat > "$t/bin/tailscale" <<STUB
#!/bin/sh
[ "\$1" = status ] && { echo "{\"BackendState\":\"\$TS_STATE\"}"; exit 0; }
echo "tailscale \$1" >> "$t/calls"
STUB
cat > "$t/bin/curl" <<'STUB'
#!/bin/sh
case "$*" in *metadata*) echo '{"client_id":"c","tags":"tag:app-host"}' ;; *token*) echo '{"token":"t"}' ;; esac
STUB
chmod +x "$t/bin/tailscale" "$t/bin/curl"
printf 'echo published >> "%s/calls"\n' "$t" > "$t/services.d/new.sh"

run() { : > "$t/calls"; TS_STATE=$1 PATH="$t/bin:$PATH" EXE_HOST_SERVICES_D="$t/services.d" sh "$here/join.sh" $2; }
fail=0
run Running publish
[ "$(cat "$t/calls")" = published ] || { echo "FAIL: 'join.sh publish' while online did not publish services.d"; fail=1; }
run Running ""
[ ! -s "$t/calls" ] || { echo "FAIL: plain join.sh while online is no longer a no-op"; fail=1; }
run NeedsLogin publish
[ ! -s "$t/calls" ] || { echo "FAIL: 'join.sh publish' while offline joined or published"; fail=1; }
run NeedsLogin ""
[ "$(cat "$t/calls")" = "$(printf 'tailscale up\npublished')" ] || { echo "FAIL: plain join.sh while offline did not join and publish"; fail=1; }
[ "$fail" = 0 ] && echo "ok: join-publish"
exit "$fail"
