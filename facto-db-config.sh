#!/bin/sh
# Write the facto-db upstream config from Neon credentials. Run on the VM as root by a fleet-run job that reads
# 1Password item 'Neon facto (personal)' and pipes FOUR LINES on stdin (never argv, never a file in the repo):
#   host (e.g. ep-xxx.us-east-2.aws.neon.tech), dbname, user, password
# Writes /etc/exe-host/facto-db/{upstream.ini,userlist.txt}, mode 0600, owned by the facto-db system user (uid 10001).
# Clients use the same user and password against svc:facto-db. Re-run to rotate; then restart the container.
set -eu
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
IFS= read -r HOST
IFS= read -r DBNAME
IFS= read -r DBUSER
IFS= read -r PASS
for v in "$HOST" "$DBNAME" "$DBUSER" "$PASS"; do
  case "$v" in
    ''|*[[:space:]\"\'\\]*) echo "empty value or whitespace/quote/backslash in input" >&2; exit 1 ;;
  esac
done
D=/etc/exe-host/facto-db
umask 077
install -d -m 0700 -o 10001 -g 10001 "$D"
printf '[databases]\n%s = host=%s port=5432 dbname=%s user=%s password=%s\n' \
  "$DBNAME" "$HOST" "$DBNAME" "$DBUSER" "$PASS" > "$D/upstream.ini.new"
printf '"%s" "%s"\n' "$DBUSER" "$PASS" > "$D/userlist.txt.new"
chown 10001:10001 "$D/upstream.ini.new" "$D/userlist.txt.new"
chmod 0600 "$D/upstream.ini.new" "$D/userlist.txt.new"
mv "$D/upstream.ini.new" "$D/upstream.ini"
mv "$D/userlist.txt.new" "$D/userlist.txt"
cd /opt/exe-host
COMPOSE_PROFILES=facto-db docker compose up -d --build facto-db
# join.sh publishes services only when it joins, so publish this one now.
sh /opt/exe-host/services.d/facto-db.sh
echo "facto-db configured for $DBNAME on $HOST (secret not echoed)"
