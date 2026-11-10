#!/bin/bash
# Stale Sessions: kim joined docker an hour ago but still gets "permission denied".
# etc/passwd and etc/group are today's database; sessions/<user>.status are the
# Uid/Gid/Groups lines of each user's running shell, from /proc/<pid>/status
# (numbers only). Four people (kim always) have a session older than a group
# change; one person's session holds a group etc/group no longer gives them (a
# revoked group is not "missing", so that user is not on the re-login list).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc sessions bin .lm-state
M="$(cd "$(dirname "$0")/../../../mocks/accounts" && pwd)"
for t in id groups getent; do cp "$M/$t" bin/; done

cat > etc/passwd <<'PW'
root:x:0:0:root:/root:/bin/bash
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
kim:x:1001:1001:Kim Larsen:/home/kim:/bin/bash
omar:x:1002:1002:Omar Haddad:/home/omar:/bin/bash
priya:x:1003:1003:Priya Nair:/home/priya:/bin/bash
lucas:x:1004:1004:Lucas Meyer:/home/lucas:/bin/bash
nora:x:1005:1005:Nora Berg:/home/nora:/bin/bash
felix:x:1006:1006:Felix Wagner:/home/felix:/bin/bash
sana:x:1007:1007:Sana Iqbal:/home/sana:/bin/bash
tom:x:1008:1008:Tom Ricci:/home/tom:/bin/bash
PW

cat > etc/group <<'GR'
root:x:0:
adm:x:4:omar,sana
sudo:x:27:
www-data:x:33:priya,sana
docker:x:998:kim,nora,sana
dev:x:2001:kim,omar,priya,felix
ops:x:2002:omar,lucas,nora,tom
kim:x:1001:
omar:x:1002:
priya:x:1003:
lucas:x:1004:
nora:x:1005:
felix:x:1006:
sana:x:1007:
tom:x:1008:
GR

# Pick 3 more stale users besides kim, and one user whose session has a revoked group.
users=(omar priya lucas nora felix sana tom)
pick=$(awk -v seed="$RANDOM" 'BEGIN {
  srand(seed); n = split("omar priya lucas nora felix sana tom", a, " ")
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  print a[1], a[2], a[3], a[4]
}')
set -- $pick
stale=" kim $1 $2 $3 "; lost=$4

pid=4100
for u in kim "${users[@]}"; do
  pid=$((pid + 37 + RANDOM % 90))
  uid=$(awk -F: -v u="$u" '$1 == u { print $3 }' etc/passwd)
  gids=$(bin/id -G "$u")            # the database view: primary first
  if [ "$u" = kim ]; then
    drop=998
  elif [[ "$stale" == *" $u "* ]]; then
    drop=$(echo $gids | tr ' ' '\n' | sed 1d | awk -v seed="$RANDOM" 'BEGIN { srand(seed) } { a[NR] = $1 } END { print a[int(rand() * NR) + 1] }')
  else
    drop=""
  fi
  have=""
  for g in $gids; do [ "$g" = "$drop" ] || have="$have$g "; done
  # the revoked-group session: still holds sudo (27) although etc/group no longer lists them
  [ "$u" = "$lost" ] && have="$have""27 "
  {
    printf 'Name:\tbash\nUmask:\t0022\nState:\tS (sleeping)\nTgid:\t%s\nPid:\t%s\nPPid:\t%s\n' "$pid" "$pid" $((pid - 3))
    printf 'Uid:\t%s\t%s\t%s\t%s\n' "$uid" "$uid" "$uid" "$uid"
    printf 'Gid:\t%s\t%s\t%s\t%s\n' "$uid" "$uid" "$uid" "$uid"
    printf 'Groups:\t%s\n' "$have"
  } > "sessions/$u.status"
done

cksum etc/passwd etc/group sessions/*.status > .lm-state/inputs
