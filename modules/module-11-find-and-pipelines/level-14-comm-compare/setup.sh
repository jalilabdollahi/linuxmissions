#!/bin/bash
# Twin Servers Drift: package dumps of web-1 and web-2. web-1's dump has
# ":amd64"/":i386" on multi-arch packages, web-2's was taken with a format
# that drops the architecture (so i386 + amd64 give duplicate names). Both are
# in install order. Which packages exist only on one host changes per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

POOL='acl adduser apparmor apt apt-utils base-files base-passwd bash bash-completion bc bind9-host bsdutils bzip2 ca-certificates certbot coreutils cron curl dash dbus debconf debianutils diffutils dmidecode dnsutils dpkg e2fsprogs file findutils fail2ban gawk gcc-14-base git git-man gnupg gpgv grep gzip haproxy hostname htop init-system-helpers iproute2 iptables iputils-ping jq less libacl1 libapparmor1 libaudit1 libblkid1 libbz2-1.0 libc-bin libc6 libcap2 libcom-err2 libcrypt1 libcurl4t64 libdb5.3t64 libexpat1 libffi8 libgcc-s1 libgcrypt20 libgd3 libgmp10 libgnutls30t64 libgpg-error0 libidn2-0 libjq1 liblz4-1 liblzma5 libmagic1t64 libmaxminddb0 libmd0 libmemcached11t64 libmount1 libncursesw6 libnghttp2-14 libonig5 libpam0g libpcre2-8-0 libpq5 libpsl5t64 libreadline8t64 libseccomp2 libselinux1 libsqlite3-0 libssl3t64 libstdc++6 libsystemd0 libtinfo6 libudev1 libunistring5 libuuid1 libxml2 libxxhash0 libzstd1 locales login logrotate lsb-release lsof memcached mount nano ncurses-base netbase netcat-openbsd nginx nginx-common openssh-client openssh-server openssl passwd perl-base php8.3-cli php8.3-common php8.3-curl php8.3-fpm php8.3-gd php8.3-intl php8.3-mbstring php8.3-mysql php8.3-opcache php8.3-redis php8.3-xml procps python3 python3-apt python3-certbot python3-minimal python3-yaml python3.12 redis-tools rsync rsyslog sed sensible-utils strace sudo systemd systemd-sysv sysstat tar tcpdump tmux tzdata ubuntu-keyring ucf unattended-upgrades unzip util-linux vim-tiny wget xz-utils zlib1g zstd'

OPTIONAL='bc certbot dmidecode fail2ban git git-man haproxy htop jq libgd3 libjq1 libmaxminddb0 libmemcached11t64 libonig5 libpq5 lsof memcached nano netcat-openbsd php8.3-gd php8.3-intl php8.3-mysql php8.3-redis python3-certbot python3-yaml redis-tools rsync strace sysstat tcpdump tmux unzip vim-tiny wget zstd'

awk -v seed="$RANDOM$$" -v pool="$POOL" -v optional="$OPTIONAL" '
function ver(name,   v) {
  v = int(rand() * 9) "." int(rand() * 20) "." int(rand() * 30)
  if (rand() < 0.5) v = v "-" int(rand() * 9 + 1) "ubuntu" int(rand() * 5 + 1)
  if (rand() < 0.15) v = int(rand() * 2 + 1) ":" v   # an epoch, as in 1:9.6p1-3ubuntu13
  return v
}
function i386(name) { return name ~ /^(libc6|libstdc\+\+6|zlib1g|libgcc-s1)$/ }
function multiarch(name) { return name ~ /^lib/ || name ~ /^(zlib1g|gcc-14-base)$/ }
BEGIN {
  srand(seed)
  n = split(pool, pkg, " ")
  # Pick the drift among the optional packages: 6-9 only on web-1, 6-9 only
  # on web-2.
  nd = split(optional, opt, " ")
  n1 = 6 + int(rand() * 4); n2 = 6 + int(rand() * 4)
  while (c1 < n1) { p = opt[int(rand() * nd) + 1]; if (!(p in where)) { where[p] = 1; c1++ } }
  while (c2 < n2) { p = opt[int(rand() * nd) + 1]; if (!(p in where)) { where[p] = 2; c2++ } }
  # libc6, libstdc++6, zlib1g and libgcc-s1 are on both, plus an i386 copy
  # for the old monitoring agent.
  for (i = 1; i <= n; i++) {
    p = pkg[i]; w = (p in where) ? where[p] : 0
    v1 = ver(p); v2 = (rand() < 0.3) ? ver(p) : v1
    if (w != 2) { a1[++k1] = p (multiarch(p) ? ":amd64" : "") "\t" v1 }
    if (w != 1) { a2[++k2] = p "\t" v2 }
    if (i386(p)) {
      a1[++k1] = p ":i386\t" v1
      a2[++k2] = p "\t" v2
    }
  }
  # an agent hiccup on web-2: a block of lines written twice
  s = int(rand() * (k2 - 10)) + 1
  for (j = s; j < s + 5; j++) a2[++k2] = a2[j]
  for (i = k1; i > 1; i--) { j = int(rand() * i) + 1; t = a1[i]; a1[i] = a1[j]; a1[j] = t }
  for (i = k2; i > 1; i--) { j = int(rand() * i) + 1; t = a2[i]; a2[i] = a2[j]; a2[j] = t }
  for (i = 1; i <= k1; i++) print a1[i] > "web1.pkgs"
  for (i = 1; i <= k2; i++) print a2[i] > "web2.pkgs"
}'

cat web1.pkgs web2.pkgs | cksum > .lm-state/inputs.sum
