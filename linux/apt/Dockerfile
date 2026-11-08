# reprepro + gpg for the Tibyan APT repository (scripts/publish-apt.sh).
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends reprepro gnupg ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /repo
