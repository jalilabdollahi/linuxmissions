#!/bin/bash
# Docker Crew: build-02's etc/group and etc/passwd. Who is in docker is drawn
# at random. Traps: the docker member list ends with a stray comma, a look-alike
# group docker-ci has its own members, and the CI service account (plus maybe
# one person) has docker as its PRIMARY group, so it never appears in the list.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc .lm-state

dgid=$((988 + RANDOM % 10))   # 988-997: 998 and 999 are taken by systemd
cigid=$((dgid - 1))           # docker-ci, a system group too

# Ten people in random order; the first four are docker members, the next two
# are only in docker-ci, and person 7 may get docker as primary group.
mapfile -t ppl < <(awk -v seed="$RANDOM" 'BEGIN {
  n = split("hana:Hana Ito|viktor:Viktor Lind|nadia:Nadia Rahman|oscar:Oscar Mendes|priya:Priya Nair|" \
            "tomas:Tomas Ruiz|wei:Wei Zhang|greta:Greta Holm|kofi:Kofi Mensah|lucia:Lucia Ferri", a, "|")
  srand(seed)
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  for (i = 1; i <= n; i++) print a[i]
}')
name() { printf '%s' "${ppl[$1]%%:*}"; }

prim_person=$((RANDOM % 2))   # 1: person 7 has docker as primary group

{
  cat <<'P'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
_apt:x:42:65534::/nonexistent:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
messagebus:x:101:101::/nonexistent:/usr/sbin/nologin
sshd:x:105:65534::/run/sshd:/usr/sbin/nologin
P
  uid=1000
  for i in 0 1 2 3 4 5 6 7 8 9; do
    login=$(name $i); full=${ppl[$i]#*:}
    gid=$uid
    [ $i = 6 ] && [ $prim_person = 1 ] && gid=$dgid
    echo "$login:x:$uid:$gid:$full,,,:/home/$login:/bin/bash"
    uid=$((uid + 1))
  done
  echo "ci-runner:x:$uid:$dgid:CI build runner,,,:/var/lib/ci-runner:/bin/bash"
} > etc/passwd

members=$(printf '%s,%s,%s,%s,' "$(name 2)" "$(name 0)" "$(name 3)" "$(name 1)")
{
  cat <<'G'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:syslog
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
www-data:x:33:
backup:x:34:
operator:x:37:
sasl:x:45:
staff:x:50:
users:x:100:
nogroup:x:65534:
systemd-journal:x:999:
systemd-network:x:998:
messagebus:x:101:
G
  echo "sudo:x:27:$(name 8)"
  echo "docker-ci:x:$cigid:$(name 4),$(name 5),ci-runner"
  echo "docker:x:$dgid:$members"
  uid=1000
  for i in 0 1 2 3 4 5 6 7 8 9; do
    if ! { [ $i = 6 ] && [ $prim_person = 1 ]; }; then echo "$(name $i):x:$uid:"; fi
    uid=$((uid + 1))
  done
  echo "build:x:1500:$(name 0),$(name 4),$(name 7),$(name 9)"
} > etc/group
cksum etc/passwd etc/group > .lm-state/inputs
