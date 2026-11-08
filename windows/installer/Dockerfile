# makensis (native Linux NSIS 3) + unzip; no Wine needed for an NSIS script.
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends nsis unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
