#!/bin/sh
# join.sh must run every services.d script even when an earlier one fails, and then exit non-zero.
# Stubs tailscale and curl on PATH; no network, no root. Run: sh tests/join-services-test.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/services.d"
cat > "$t/bin/tailscale" <<'STUB'
#!/bin/sh
[ "$1" = status ] && { echo '{"BackendState":"NeedsLogin"}'; exit 0; }
exit 0
STUB
cat > "$t/bin/curl" <<'STUB'
#!/bin/sh
case "$*" in *metadata*) echo '{"client_id":"c","tags":"tag:app-host"}' ;; *token*) echo '{"token":"t"}' ;; esac
STUB
chmod +x "$t/bin/tailscale" "$t/bin/curl"
# Sorted like the real directory: a failing service (facto-db's unverified --service syntax) before proof and tatami.
printf 'exit 1\n' > "$t/services.d/a-fails.sh"
printf 'echo b >> "%s/published"\n' "$t" > "$t/services.d/b-ok.sh"
printf 'echo c >> "%s/published"\n' "$t" > "$t/services.d/c-ok.sh"

rc=0
PATH="$t/bin:$PATH" EXE_HOST_SERVICES_D="$t/services.d" sh "$here/join.sh" 2>"$t/err" || rc=$?
fail=0
[ "$(cat "$t/published" 2>/dev/null)" = "$(printf 'b\nc')" ] || { echo "FAIL: services after the failing one were not published"; fail=1; }
[ "$rc" -ne 0 ] || { echo "FAIL: join.sh exited 0 although a service failed"; fail=1; }
grep -q a-fails "$t/err" || { echo "FAIL: the failing script is not named on stderr"; fail=1; }
[ "$fail" = 0 ] && echo "ok: join-services"
exit "$fail"
