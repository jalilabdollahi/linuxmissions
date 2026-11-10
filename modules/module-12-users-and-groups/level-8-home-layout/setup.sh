#!/bin/bash
# Home audit on files-01: etc/passwd says where homes should be, home/ is what is
# on disk. Which people lack a home and which dirs belong to nobody changes on
# each run. Traps: passwd paths are /home/x (the sandbox has ./home/x); service
# homes (/var/lib/postgresql, /srv/ftp, /nonexistent) are out of scope; the dir
# "Bob" is not user "bob"'s home (case matters); hidden and look-alike dirs
# (dmitri.bak, .migrate-tmp) are orphans; a plain file in home/ is not a dir;
# reports has home /home/rpt, so account and directory names differ; modes are
# wrong in several ways (755, 777, 700, 775), and files inside must keep theirs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc home .lm-state

# random: two of these four people lost their home directory
gone=$(awk -v seed="$RANDOM" 'BEGIN { srand(seed); split("carol erin hiro grace", a, " ")
  for (i = 4; i > 1; i--) { j = int(rand() * i) + 1; t = a[i]; a[i] = a[j]; a[j] = t }
  print a[1], a[2] }')

cat > etc/passwd <<'PW'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
postgres:x:115:123:PostgreSQL administrator,,,:/var/lib/postgresql:/bin/bash
ftp:x:116:124:ftp daemon:/srv/ftp:/usr/sbin/nologin
sshd:x:105:65534::/run/sshd:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
alice:x:1000:1000:Alice Moreau:/home/alice:/bin/bash
bob:x:1001:1001:Bob Keller:/home/bob:/bin/bash
carol:x:1002:1002:Carol Diaz:/home/carol:/bin/bash
dmitri:x:1003:1003:Dmitri Orlov:/home/dmitri:/bin/bash
erin:x:1004:1004:Erin Walsh:/home/erin:/bin/bash
farid:x:1005:1005:Farid Nasser:/home/farid:/bin/bash
grace:x:1006:1006:Grace Lin:/home/grace:/bin/bash
hiro:x:1007:1007:Hiro Tanaka:/home/hiro:/bin/bash
reports:x:1008:1008:Reporting jobs:/home/rpt:/bin/bash
PW

modes=(755 777 700 750 775 755 700 750)
i=0
for u in alice bob carol dmitri erin farid grace hiro; do
  case " $gone " in *" $u "*) continue ;; esac
  mkdir -p "home/$u"
  echo "# $u's shell profile" > "home/$u/.profile"
  echo "export EDITOR=vi" > "home/$u/.bashrc"
  mkdir -p "home/$u/work"; echo "notes of $u" > "home/$u/work/notes.txt"
  chmod 644 "home/$u/.profile" "home/$u/.bashrc" "home/$u/work/notes.txt"
  chmod 755 "home/$u/work"
  chmod "${modes[$i]}" "home/$u"
  i=$((i + 1))
done
# a mode-0750 home is correct from the start; make sure at least four need fixing
mkdir -p home/rpt; echo "weekly report" > home/rpt/report.sh; chmod 644 home/rpt/report.sh; chmod 755 home/rpt

# orphans: nobody's home (names from deleted accounts, backups, a case mix-up, a hidden one)
for d in Bob dmitri.bak jonas .migrate-tmp; do
  mkdir -p "home/$d"; echo "left over" > "home/$d/data.txt"; chmod 644 "home/$d/data.txt"
  chmod 755 "home/$d"
done
echo "quota file, not a directory" > home/README

# modes of everything inside the homes must stay as they are
find home -mindepth 2 | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(stat -c %a "$f")" "$f"; done > .lm-state/inner
cksum etc/passwd > .lm-state/inputs
