#!/bin/sh
# Writes /etc/exe-host/facto/env and enables the facto server. Run as root on exe-host after facto-pg is up.
# DATABASE_URL is built from the facto-pg password file with the password percent-encoded (base64 passwords contain + / =).
set -eu
pw_file=/etc/exe-host/facto-pg/password
[ -s "$pw_file" ] || { echo "missing $pw_file" >&2; exit 1; }
install -d -o 10004 -g 10004 -m 0700 /etc/exe-host/facto
install -d -o 10004 -g 10004 -m 0700 /srv/state/facto /srv/state/facto/blobs
enc=$(tr -d '\n' < "$pw_file" | jq -sRr @uri)
umask 077
{
  printf 'DATABASE_URL=postgres://facto:%s@127.0.0.1:5432/facto\n' "$enc"
  printf 'BIND_ADDR=127.0.0.1:8877\n'
  printf 'GRAPHDB_BLOB_STORE=local_fs\n'
  printf 'GRAPHDB_BLOB_DIR=/state/blobs\n'
} > /etc/exe-host/facto/env
chown 10004:10004 /etc/exe-host/facto/env
chmod 0400 /etc/exe-host/facto/env
touch /etc/exe-host/facto/enabled
echo "facto configured; run /opt/exe-host/bootstrap.sh"
