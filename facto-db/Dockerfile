# facto-db: pgbouncer in front of Neon. Built on the VM from this repo; no third-party image to pin.
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends pgbouncer ca-certificates \
 && rm -rf /var/lib/apt/lists/*
COPY pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
# Runs as uid 10001 (compose `user:`), the host's facto-db system user. Never root.
USER 10001:10001
EXPOSE 5432
CMD ["pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
