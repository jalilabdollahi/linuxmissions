# Reference environment for scripts/test_levels.py: Ubuntu, non-root player,
# with the tools levels are allowed to rely on.
FROM ubuntu:24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      python3 python3-rich \
      procps psmisc cron logrotate sudo \
      curl jq bc gawk file xxd bsdextrautils less nano vim-tiny \
      tar gzip bzip2 xz-utils zip unzip zstd \
      iproute2 iputils-ping dnsutils net-tools netcat-openbsd tcpdump \
      acl attr quota util-linux coreutils findutils diffutils patch tree \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash player
USER player
WORKDIR /app
