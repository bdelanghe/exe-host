#!/bin/sh
# exe.dev first-boot script (`ssh exe.dev new --setup-script /dev/stdin < setup.sh`). Size-limited, so it only
# fetches the repo and hands off to bootstrap.sh. Contains no secrets and does not join the tailnet (see join.sh).
set -eu
REPO=${EXE_HOST_REPO:-https://github.com/bdelanghe/exe-host.git}
[ "$(id -u)" = 0 ] || exec sudo -E sh "$0" "$@"
command -v git >/dev/null 2>&1 || { apt-get update -y && apt-get install -y git; }
rm -rf /opt/exe-host
git clone --depth 1 "$REPO" /opt/exe-host
exec sh /opt/exe-host/bootstrap.sh
