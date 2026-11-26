#!/bin/sh
# backup.sh must not file-copy facto-pg's live data directory (README, Backups: "Not covered: Postgres ... not a file
# copy of a live data directory"; it is ~88 GB). Stubs restic on PATH and points backup.sh at a temp config dir.
# Run: sh tests/backup-excludes-pg-test.sh
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/etc"
printf 'RESTIC_REPOSITORY=s3:x\nRESTIC_PASSWORD=p\n' > "$t/etc/backup.env"
printf 'AWS_ACCESS_KEY_ID=a\nAWS_SECRET_ACCESS_KEY=s\nAWS_SESSION_TOKEN=t\nCRED_EXPIRES=%s\n' $(( $(date +%s) + 3600 )) \
  > "$t/etc/r2-cred.env"
printf '#!/bin/sh\necho "$*" >> "%s/restic"\n' "$t" > "$t/bin/restic"
chmod +x "$t/bin/restic"

PATH="$t/bin:$PATH" EXE_HOST_ETC="$t/etc" sh "$here/backup.sh"
line=$(grep '^backup ' "$t/restic") || { echo "FAIL: restic backup was not run"; exit 1; }
case " $line " in
  *" /srv/state "*) ;;
  *) echo "FAIL: /srv/state is no longer backed up: $line"; exit 1 ;;
esac
case " $line " in
  *" --exclude /srv/state/facto-pg "*) echo "ok: backup-excludes-pg" ;;
  *) echo "FAIL: facto-pg's live data directory is in the backup: $line"; exit 1 ;;
esac
