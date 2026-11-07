# Runtime for the graphdb binary built on the host (/srv/build/facto-target/release). Not pinned by digest: pin it once pulled.
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends libssl3 ca-certificates \
 && rm -rf /var/lib/apt/lists/*
