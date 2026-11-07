# exe-host

The always-on host that replaces phobos for services Bobby uses while away. One exe.dev VM, on the personal tailnet by
exe.dev workload identity (no stored key), backups to Cloudflare R2. Everything on it is this repo: no hand-configured state.

Plan: `~/.lobby/ops/decisions/PLAN-2026-11-06-off-phobos-by-nov-12.md`. This repo is step 1 (the host and a proof service).

## What is where

| file | role |
| --- | --- |
| `setup.sh` | exe.dev first-boot script (`new --setup-script`). Size-limited: clones this repo, runs `bootstrap.sh`. No secrets. |
| `bootstrap.sh` | idempotent: docker, tailscale, restic; `docker compose up -d --build`; installs the timers. |
| `compose.yaml` | the services. One entry each: image (or build dir), loopback port, state under `/srv/state/<name>`. |
| `services.d/<name>.sh` | publishes one service on the tailnet (`tailscale serve`). Run by `join.sh`. |
| `join.sh` | joins the tailnet with exe.dev's token; no-op while online; re-runs every 10 min (`exe-host-join.timer`). |
| `backup.sh` | restic of `/srv/state` to R2, hourly (`exe-host-backup.timer`); `backup.sh restore DIR` for the drill. |
| `proof/` | the proof service: busybox httpd + a CGI that prints host, UTC time and a hit counter kept in `/srv/state/proof`. |

## Tags and ACLs

- **Tailnet:** `tail556f5b` (personal). Policy is code: `bdelanghe/tailnet-policy`, `policy.hujson`. Edit it by PR; a console edit is overwritten by the next apply and flagged by the drift job.
- **Tag:** `tag:host`, in `tagOwners` as `["autogroup:admin"]`. Only Bobby can apply it by hand.
- **Trust credential** (Tailscale admin, Settings, Trust credentials): type OpenID Connect, issuer = the exe.dev **Issuer**, subject = the exe.dev **Subject** exactly (never `*`), scope **Auth Keys: write** only (never OAuth Keys, Federated Keys or All), tag `tag:host`. One credential per exe.dev integration.
- **exe.dev integration** `tailscale-wif` (Identity Federation, consumer `tailscale`), attached to `vm:exe-host`. Metadata `client_id=<Client ID>`, `tags=tag:host`. Reachable only from an attached VM at `https://tailscale-wif.int.exe.xyz` (`/metadata`, `/token`, tokens last 5 minutes).
- **Node:** joins with `tailscale up --client-id=<id>?ephemeral=true&preauthorized=true --id-token=… --advertise-tags=tag:host --hostname=exe-host`. Ephemeral: Tailscale deletes it when it goes offline, and `exe-host-join.timer` re-joins it with a fresh token when it is back.
- **Reach:** the existing `* -> *` grant covers `tag:host`. That means the host can dial every device and the reverse. Tightening it (members -> all, `tag:host` -> only what it must dial) is a follow-up PR, not part of step 1, because it must not strand `tag:fleet-lab`.
- **Policy test:** `bdelanghe@github` accepts `tag:host:80`.
- **Not exposed:** exe.dev's own HTTPS proxy (`exe-host.exe.xyz`) is private by default and stays that way. Never `share set-public` a service that is meant for the tailnet. Services bind `127.0.0.1` only.

## Adding the next service

Each service keeps its tailnet name; the host is one node, so a name is a hostname on it or a port.

1. **Image.** Add `services:<name>` to `compose.yaml` with `build: ./<name>` (a Dockerfile in this repo) or `image: ghcr.io/…@sha256:…` (pin the digest). Bind `127.0.0.1:<port>:<port>`, state under `/srv/state/<name>:/state` so the hourly backup covers it. Secrets are never in the repo: an `env_file: /etc/exe-host/<name>.env` written by a fleet-run job from 1Password.
2. **Setup script.** `bootstrap.sh` is the setup script; it is idempotent, so add any package or unit the service needs there. `setup.sh` only changes if the first-boot hand-off changes.
3. **Tailnet name.** Add `services.d/<name>.sh` with a `tailscale serve --bg --http=<tailnet port> http://127.0.0.1:<port>` (or `--https=` for TLS, which needs HTTPS enabled in the tailnet DNS settings). The service is then `http://exe-host:<tailnet port>`.
   If a service must keep its old name (for example `facto-api`) and clients should not change, give it its own node: a second tailnet node needs its own `tailscale` state (a sidecar container or a second VM) with its own `--hostname`. Not proven yet; decide with the facto move (step 2).
4. **Ship.** PR here, merge, then on the VM `git -C /opt/exe-host pull && sudo /opt/exe-host/bootstrap.sh` (a fleet-run job; sessions cannot reach exe.dev). Then check from the phone with phobos's lid closed.
5. **Rollback.** Stop the service here (`docker compose stop <name>`, `tailscale serve --http=<port> off`); start the phobos copy again. The phobos copy is stopped, not deleted, until the move is confirmed.

## Backups

- Restic repository `s3:https://<account>.r2.cloudflarestorage.com/<bucket>/exe-host`, client-side encrypted (the restic password and the R2 keys live only in 1Password `Fleet/exe-host-r2-backup` and in `/etc/exe-host/backup.env`, mode 0600 root).
- Hourly snapshots of `/srv/state`; keep 7 daily, 4 weekly, 6 monthly.
- **Restore drill** (done once, recorded in the report): `sudo exe-host-backup restore /tmp/restore`, compare the proof counter.
- **Not covered:** Postgres. facto-pg needs `pg_dump`/WAL archiving, not a file copy of a live data directory. That belongs to step 2.

## Cost

- exe.dev is a flat subscription with pooled resources, 50 VMs per plan: $15/mo (2 vCPU, 4 GiB, 100 GB disk, 200 GB bandwidth), $35/mo (4 vCPU, 8 GiB, 200 GB), $75/mo (8 vCPU, 16 GiB, 400 GB), $155/mo (16 vCPU, 32 GiB, 800 GB). (exe.dev/pricing, 2026-11-07.) This VM is within whatever plan already carries fleet-lab: no added cost for the proof.
- Step 2 changes this: facto-pg is 88 GB before pruning, so the 100 GB plan does not hold it with anything else. Plan on the $35 tier at least (or prune first).
- R2: $0.015 per GB-month stored, no egress fees, 10 GB free. The proof service backs up kilobytes: $0.

## Not proven yet

- exe.dev's CLI verbs for `integrations` and `new` were written from the published docs and have not been run by an agent (sessions cannot reach exe.dev). The first fleet-run job is the test; its output is recorded in the report.
- Image is built on the VM from this repo, not pulled from a registry. A GitHub Actions build to ghcr with a pinned digest is the next improvement.
