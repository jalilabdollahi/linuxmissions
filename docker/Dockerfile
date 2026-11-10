# The LinuxMissions environment: used by `./play.sh --docker` and by the level
# test runner (scripts/test-levels-docker.sh). Levels may rely on every tool
# installed here. The game itself always runs as the non-root user `player`.
FROM ubuntu:24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      python3 python3-rich python3-yaml \
      procps psmisc sysstat lsof cron logrotate sudo \
      curl wget jq bc gawk file xxd bsdextrautils binutils less nano vim-tiny git \
      tar gzip bzip2 xz-utils zip unzip zstd cpio rsync \
      iproute2 iputils-ping dnsutils net-tools netcat-openbsd tcpdump \
      openssh-client openssl gettext-base \
      acl attr quota util-linux coreutils findutils diffutils patch tree \
      e2fsprogs fdisk \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash player
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh
ENV PYTHONPATH=/app TERM=xterm-256color LANG=C.UTF-8
WORKDIR /app
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["python3", "-m", "engine.engine"]
