#!/bin/sh
# Back up /srv/state to Cloudflare R2 with restic (encrypted client-side). Credentials live only in
# /etc/exe-host/backup.env (0600, root), written by the fleet-run job from 1Password. See README.
#   backup.sh            snapshot, then prune (keep 7 daily / 4 weekly / 6 monthly)
#   backup.sh restore D  restore the latest snapshot into directory D (restore drill)
set -eu
. /etc/exe-host/backup.env   # RESTIC_REPOSITORY, RESTIC_PASSWORD, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
export RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

restic snapshots >/dev/null 2>&1 || restic init

if [ "${1:-}" = restore ]; then
  restic restore latest --target "${2:?restore target dir}"
  exit 0
fi

restic backup /srv/state --tag exe-host
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
