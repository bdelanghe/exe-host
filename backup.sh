#!/bin/sh
# Back up /srv/state to Cloudflare R2 with restic (encrypted client-side).
# Two root-only files, 0600, in /etc/exe-host:
#   backup.env    static: RESTIC_REPOSITORY, RESTIC_PASSWORD (written once by the fleet-run job from 1Password)
#   r2-cred.env   short-lived: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN, CRED_EXPIRES (epoch seconds)
#                 minted by a CI job and pushed here; nothing long-lived R2 is stored anywhere. See README and
#                 RECOMMEND-2026-11-07-exe-host-backup-credential.md. The file's source is swappable (a broker door later).
#   backup.sh            snapshot, then prune (keep 7 daily / 4 weekly / 6 monthly)
#   backup.sh restore D  restore the latest snapshot into directory D (restore drill)
set -eu
. /etc/exe-host/backup.env
[ -r /etc/exe-host/r2-cred.env ] || { echo "backup: no R2 credential at /etc/exe-host/r2-cred.env (pusher has not run)" >&2; exit 1; }
. /etc/exe-host/r2-cred.env
if [ "$(date +%s)" -ge "${CRED_EXPIRES:?r2-cred.env has no CRED_EXPIRES}" ]; then
  echo "backup: R2 credential expired (CRED_EXPIRES=$CRED_EXPIRES); the pusher is not refreshing it" >&2
  exit 1
fi
export RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

restic snapshots >/dev/null 2>&1 || restic init

if [ "${1:-}" = restore ]; then
  restic restore latest --target "${2:?restore target dir}"
  exit 0
fi

restic backup /srv/state --tag exe-host
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
