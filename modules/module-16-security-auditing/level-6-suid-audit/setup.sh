#!/bin/bash
# Who Gave That Root? An unpacked image rootfs/ with the usual setuid
# programs (all in the baseline) plus unexpected ones. Always unexpected: a
# copy of a shell named .cache-helper in a dot directory, and
# /usr/local/bin/pkexec (the baseline lists /usr/bin/pkexec, which is not
# set up with a bit: same name, different path). Extra unexpected files are
# drawn at random. Files are stubs; only the modes matter.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf rootfs .lm-state suid-baseline.txt; mkdir -p rootfs .lm-state
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

mk() {  # mk MODE PATH-IN-IMAGE
  local f="rootfs$2"; mkdir -p "$(dirname "$f")"
  printf '#!/bin/sh\n# stub of %s\nexit 0\n' "$2" > "$f"; chmod "$1" "$f"
}

# Expected setuid / setgid programs: these are in the baseline.
base=("4755 /usr/bin/passwd" "4755 /usr/bin/sudo" "4755 /usr/bin/su" "4755 /usr/bin/chsh" "4755 /usr/bin/chfn"
      "4755 /usr/bin/newgrp" "4755 /usr/bin/gpasswd" "2755 /usr/bin/chage" "2755 /usr/bin/wall" "2755 /usr/bin/ssh-agent"
      "2755 /usr/sbin/unix_chkpwd" "4755 /usr/bin/mount" "4755 /usr/bin/umount" "4754 /usr/lib/openssh/ssh-keysign")
for e in "${base[@]}"; do mk "${e%% *}" "${e#* }"; done
# Baseline lists pkexec, but the image does not have it there.
{
  echo "# suid-baseline.txt - setuid/setgid programs expected on image web-base-2026.3"
  echo "# generated from the golden image; one path per line"
  echo
  for e in "${base[@]}"; do echo "${e#* }"; done
  echo "/usr/bin/pkexec"
} > suid-baseline.txt

# Harmless files that must stay alone.
mk 755 /usr/bin/ls; mk 755 /usr/bin/awk; mk 700 /usr/bin/at; mk 644 /etc/passwd; mk 755 /usr/bin/ssh
mk 1777 /var/tmp/.keep

# Always unexpected.
unexpected=("/var/tmp/.x11-cache/.cache-helper" "/usr/local/bin/pkexec")
mk "$(pick 4755 6755 4711)" /var/tmp/.x11-cache/.cache-helper
mk 4755 /usr/local/bin/pkexec
# Random extras (3 of 6).
pool=("2755 /home/deploy/bin/backup" "4711 /opt/legacy/bin/ping6" "6750 /srv/data/.recover" "4755 /opt/vendor/agent/helper"
      "2711 /usr/local/sbin/logwatch" "4644 /usr/share/doc/support/readme-helper")
for i in $(printf '%s\n' 0 1 2 3 4 5 | awk -v s="$RANDOM" 'BEGIN{srand(s)} {print rand(), $0}' | sort -n | head -3 | cut -d' ' -f2); do
  e=${pool[$i]}; mk "${e%% *}" "${e#* }"; unexpected+=("${e#* }")
done
printf '%s\n' "${unexpected[@]}" | LC_ALL=C sort > .lm-state/expected

mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
find rootfs -type f | LC_ALL=C sort | while IFS= read -r p; do printf '%s\t%s\n' "$p" "$(mode "$p")"; done > .lm-state/modes
