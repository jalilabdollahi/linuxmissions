#!/bin/bash
# image/ is a bastion image tree with CHECKLIST.md (12 points). Three or four randomly chosen
# points are already compliant (and must stay so); the others are broken in one of several
# ways, with the traps from the curriculum: an sshd drop-in that wins over the main file, an
# omitted keyword whose default is bad, a Match block that overrides, a umask in a file that
# profile.d never loads, extra SUID files, secrets in env files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf image bin CHECKLIST.md .lm-state; mkdir -p .lm-state bin
MOCK="$(cd "$(dirname "$0")/../../../mocks/security" && pwd)"
cp "$MOCK/sshd" bin/sshd; chmod 755 bin/sshd
I=image
mkdir -p $I/etc/ssh/sshd_config.d $I/etc/sudoers.d $I/etc/profile.d $I/etc/cron.d $I/etc/app $I/home/admin/.ssh \
         $I/usr/bin $I/usr/local/bin $I/opt/app $I/opt/tools $I/tmp $I/var/tmp
rnd() { LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"; }
pickv() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

# which items are compliant: 3 or 4 random ones
declare -A ok
for i in $(seq 1 12); do ok[$i]=0; done
n=$((3 + RANDOM % 2)); c=0
while [ $c -lt $n ]; do i=$((1 + RANDOM % 12)); [ "${ok[$i]}" = 0 ] && { ok[$i]=1; c=$((c + 1)); }; done

cat > CHECKLIST.md <<'MD'
# Bastion image: go-live checklist

All paths are relative to image/. Every point is checked on its own.

1. sshd: PermitRootLogin is `no` in the effective configuration (what `sshd -T` reports, for every user).
2. sshd: PasswordAuthentication is `no` in the effective configuration, for every user.
3. sshd: MaxAuthTries is 4 or less in the effective configuration.
   (Points 1 to 3 also need `sshd -t` to pass and every other sshd setting to stay as it is.)
4. The SSH host private keys etc/ssh/ssh_host_*_key are mode 600 (the .pub files stay 644).
5. home/admin/.ssh is mode 700 and its authorized_keys is mode 600.
6. sudo: no active rule gives NOPASSWD for ALL commands, the admin group keeps its sudo rule (with a password), and every file passes `visudo -cf`.
7. A new login shell gets a umask that removes group write and all access for others (027 or stricter), set in etc/profile.d.
8. /tmp (tmp/) is world-writable with the sticky bit (1777).
9. The only setuid/setgid files are those listed in etc/suid-baseline.txt, and those keep their bits.
10. Interactive shells never save commands that start with a space (etc/bash.bashrc).
11. No plaintext secrets in the image: no `PASSWORD`, `SECRET`, `TOKEN` or `API_KEY` setting with a real value (placeholders such as <...> or ${...} are fine), no AWS access key id. The files stay, minus the secret values.
12. No regular file in the image is world-writable (etc/cron.d/backup and opt/app/run.sh must still exist).
MD

# ---- sshd (1-3) ----------------------------------------------------------------------
# variants: main (bad value in main file) | dropin (a drop-in, included first, wins) | omit (bad default) | match (Match User deploy overrides)
declare -A var; declare -A badv=( [1]="PermitRootLogin yes" [2]="PasswordAuthentication yes" [3]="MaxAuthTries 6" )
goodv=( "" "PermitRootLogin no" "PasswordAuthentication no" "MaxAuthTries 3" )
main_lines=(); drop_lines=(); matchline=""
for i in 1 2 3; do
  if [ "${ok[$i]}" = 1 ]; then main_lines+=("${goodv[i]}"); continue; fi
  v=$(pickv main dropin omit); [ "$i" = 2 ] && v=$(pickv main dropin omit match)
  case $v in
    main)   main_lines+=("${badv[i]}") ;;
    dropin) main_lines+=("${goodv[i]}"); drop_lines+=("${badv[i]}") ;;
    omit)   ;;
    match)  main_lines+=("${goodv[i]}"); matchline="    PasswordAuthentication yes" ;;
  esac
done
{
  echo "# /etc/ssh/sshd_config - bastion"
  echo "Include sshd_config.d/*.conf"
  echo "Port 22"
  echo "HostKey /etc/ssh/ssh_host_ed25519_key"
  echo "HostKey /etc/ssh/ssh_host_rsa_key"
  printf '%s\n' "${main_lines[@]}"
  echo "PubkeyAuthentication yes"
  echo "X11Forwarding no"
  echo "Subsystem sftp /usr/lib/openssh/sftp-server"
  printf '\nMatch User deploy\n    AllowTcpForwarding no\n'
  [ -n "$matchline" ] && echo "$matchline"
} > $I/etc/ssh/sshd_config
{ echo "# cloud-init"; echo "UsePAM yes"; echo "ClientAliveInterval 120"; [ ${#drop_lines[@]} -gt 0 ] && printf '%s\n' "${drop_lines[@]}"; } > $I/etc/ssh/sshd_config.d/10-cloud-init.conf
chmod 644 $I/etc/ssh/sshd_config $I/etc/ssh/sshd_config.d/*.conf

# ---- host keys (4) and admin ssh files (5) ------------------------------------------------------
for k in ed25519 rsa; do
  printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nFAKE-%s (training data)\n-----END OPENSSH PRIVATE KEY-----\n' "$(rnd 30)" > $I/etc/ssh/ssh_host_${k}_key
  printf 'ssh-%s AAAAFAKE%s root@bastion\n' "$k" "$(rnd 24)" > $I/etc/ssh/ssh_host_${k}_key.pub
  chmod 600 $I/etc/ssh/ssh_host_${k}_key; chmod 644 $I/etc/ssh/ssh_host_${k}_key.pub
done
[ "${ok[4]}" = 0 ] && chmod "$(pickv 640 644 660)" $I/etc/ssh/ssh_host_$(pickv ed25519 rsa)_key
printf 'ssh-ed25519 AAAAFAKE%s admin@laptop\n' "$(rnd 24)" > $I/home/admin/.ssh/authorized_keys
chmod 700 $I/home/admin/.ssh; chmod 600 $I/home/admin/.ssh/authorized_keys
if [ "${ok[5]}" = 0 ]; then case $((RANDOM % 3)) in 0) chmod 755 $I/home/admin/.ssh ;; 1) chmod 644 $I/home/admin/.ssh/authorized_keys ;; 2) chmod 755 $I/home/admin/.ssh; chmod 664 $I/home/admin/.ssh/authorized_keys ;; esac; fi

# ---- sudo (6) -----------------------------------------------------------------------------------
printf '# /etc/sudoers\nDefaults\tenv_reset\nroot\tALL=(ALL:ALL) ALL\n@includedir /etc/sudoers.d\n' > $I/etc/sudoers
printf 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart app.service\n' > $I/etc/sudoers.d/10-deploy
if [ "${ok[6]}" = 1 ]; then echo '%admin ALL=(ALL:ALL) ALL' > $I/etc/sudoers.d/90-admin; else echo '%admin ALL=(ALL) NOPASSWD: ALL' > $I/etc/sudoers.d/90-admin; fi
chmod 440 $I/etc/sudoers $I/etc/sudoers.d/*

# ---- umask (7) -----------------------------------------------------------------------------------------
printf '# locale defaults\nexport LANG=C.UTF-8\n' > $I/etc/profile.d/10-locale.sh
if [ "${ok[7]}" = 1 ]; then printf '# hardening\numask 027\n' > $I/etc/profile.d/99-umask.sh
else case $((RANDOM % 3)) in
  0) printf '# hardening\numask 027\n' > $I/etc/profile.d/99-umask.conf ;;
  1) printf '# hardening\numask 022\n' > $I/etc/profile.d/99-umask.sh ;;
  2) printf '# umask is set elsewhere\n' > $I/etc/profile.d/99-umask.sh ;;
esac; fi

# ---- /tmp (8) -------------------------------------------------------------------------------------------
chmod 1777 $I/var/tmp
if [ "${ok[8]}" = 1 ]; then chmod 1777 $I/tmp; else chmod 777 $I/tmp; fi

# ---- SUID (9) ----------------------------------------------------------------------------------------------
for f in usr/bin/sudo usr/bin/passwd usr/bin/mount; do printf '#!/bin/sh\n# fake %s\n' "$f" > $I/$f; chmod 4755 $I/$f; done
printf '#!/bin/sh\n# fake wall\n' > $I/usr/bin/wall; chmod 2755 $I/usr/bin/wall
printf '%s\n' usr/bin/sudo usr/bin/passwd usr/bin/mount usr/bin/wall > $I/etc/suid-baseline.txt
printf '#!/bin/sh\n# helper\n' > $I/opt/tools/.helper; chmod 755 $I/opt/tools/.helper
printf '#!/bin/sh\n# find-root\n' > $I/usr/local/bin/rootsh; chmod 755 $I/usr/local/bin/rootsh
if [ "${ok[9]}" = 0 ]; then
  chmod 4755 $I/opt/tools/.helper
  [ $((RANDOM % 2)) -eq 0 ] && chmod 6755 $I/usr/local/bin/rootsh
fi

# ---- history (10) ---------------------------------------------------------------------------------------------
{ echo "# /etc/bash.bashrc"; echo 'PS1="\u@\h:\w\\$ "'; echo "HISTSIZE=2000"
  if [ "${ok[10]}" = 1 ]; then echo "HISTCONTROL=ignoreboth"; elif [ $((RANDOM % 2)) -eq 0 ]; then echo "HISTCONTROL=ignoredups"; fi
} > $I/etc/bash.bashrc

# ---- secrets (11) ---------------------------------------------------------------------------------------------------
if [ "${ok[11]}" = 1 ]; then
  printf 'APP_ENV=production\nDB_HOST=db.internal\nDB_PASSWORD=${DB_PASSWORD}\nAWS_ACCESS_KEY_ID=<set at deploy time>\n' > $I/etc/app/app.env
  printf 'EDITOR=vim\nAPI_TOKEN=<set at deploy time>\n' > $I/home/admin/.env
else
  printf 'APP_ENV=production\nDB_HOST=db.internal\nDB_PASSWORD=Pw-%s\n' "$(rnd 10)" > $I/etc/app/app.env
  [ $((RANDOM % 2)) -eq 0 ] && printf 'AWS_ACCESS_KEY_ID=AKIA%s\n' "$(LC_ALL=C tr -dc 'A-Z0-9' < /dev/urandom | head -c 16)" >> $I/etc/app/app.env
  printf 'EDITOR=vim\nAPI_TOKEN=tok_%s\n' "$(rnd 20)" > $I/home/admin/.env
fi
chmod 644 $I/etc/app/app.env; chmod 600 $I/home/admin/.env

# ---- world-writable files (12) ------------------------------------------------------------------------------
printf '0 3 * * * root /opt/app/run.sh\n' > $I/etc/cron.d/backup
printf '#!/bin/sh\necho run\n' > $I/opt/app/run.sh
if [ "${ok[12]}" = 1 ]; then chmod 644 $I/etc/cron.d/backup; chmod 755 $I/opt/app/run.sh; else chmod 666 $I/etc/cron.d/backup; chmod 777 $I/opt/app/run.sh; fi

# baseline of the other sshd settings (everything except the three keywords)
python3 "$MOCK/sshd" -T -f $I/etc/ssh/sshd_config | grep -vE '^(permitrootlogin|passwordauthentication|maxauthtries) ' > .lm-state/sshd.base
python3 "$MOCK/sshd" -T -f $I/etc/ssh/sshd_config -C user=deploy,host=ci,addr=192.0.2.10 | grep -vE '^(permitrootlogin|passwordauthentication|maxauthtries) ' > .lm-state/sshd.base.deploy
