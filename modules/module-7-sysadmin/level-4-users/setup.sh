#!/bin/bash
# New Hire: real-format etc/passwd and etc/group plus mock useradd, usermod,
# userdel, id and groups that edit them the way the shadow-utils tools do
# (Ubuntu defaults: shell /bin/sh, no home dir without -m, one private group
# per user). Trap: `usermod -G` without -a replaces all supplementary groups.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc/skel home/sam home/lee

cat > etc/passwd <<'EOF'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
systemd-network:x:998:998:systemd Network Management:/:/usr/sbin/nologin
sam:x:1001:1001:Sam Ortiz,,,:/home/sam:/bin/bash
lee:x:1002:1002:Lee Chen,,,:/home/lee:/bin/bash
EOF

cat > etc/group <<'EOF'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:syslog,sam
sudo:x:27:sam
www-data:x:33:
users:x:100:
nogroup:x:65534:
systemd-network:x:998:
docker:x:999:lee
sam:x:1001:
lee:x:1002:
dev:x:1050:sam,lee
EOF

printf '# ~/.bashrc: executed by bash(1) for non-login shells.\n' > etc/skel/.bashrc
printf '# ~/.profile: executed by the command interpreter for login shells.\n' > etc/skel/.profile
cp etc/skel/.bashrc etc/skel/.profile home/sam/
cp etc/skel/.bashrc etc/skel/.profile home/lee/

# ---------------------------------------------------------------- useradd
cat > useradd <<'SCRIPT'
#!/bin/bash
# Mock useradd for LinuxMissions: edits ./etc/passwd and ./etc/group, and
# creates homes under ./home. Options: -m -M -s SHELL -c COMMENT -G GROUPS
# -g GROUP -u UID -d HOME. Defaults follow Ubuntu: SHELL=/bin/sh, no home
# directory unless -m, a private group named after the user.
ROOT="$(cd "$(dirname "$0")" && pwd)"; P="$ROOT/etc/passwd"; G="$ROOT/etc/group"
usage() { echo "Usage: useradd [options] LOGIN  (mock: -m -M -s -c -G -g -u -d)" >&2; exit 2; }
mkhome=0; shell=/bin/sh; comment=""; groups=""; pgroup=""; uid=""; home=""
args=()
for a in "$@"; do
  case "$a" in
    --create-home) args+=(-m) ;; --no-create-home) args+=(-M) ;;
    --shell) args+=(-s) ;; --comment) args+=(-c) ;; --groups) args+=(-G) ;;
    --gid) args+=(-g) ;; --uid) args+=(-u) ;; --home-dir) args+=(-d) ;;
    --shell=*) args+=(-s "${a#*=}") ;; --comment=*) args+=(-c "${a#*=}") ;;
    --groups=*) args+=(-G "${a#*=}") ;; --home-dir=*) args+=(-d "${a#*=}") ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"
while getopts ":mMs:c:G:g:u:d:" o; do
  case "$o" in
    m) mkhome=1 ;; M) mkhome=0 ;; s) shell="$OPTARG" ;; c) comment="$OPTARG" ;;
    G) groups="$OPTARG" ;; g) pgroup="$OPTARG" ;; u) uid="$OPTARG" ;; d) home="$OPTARG" ;;
    :) echo "useradd: option requires an argument -- '$OPTARG'" >&2; usage ;;
    *) echo "useradd: invalid option -- '$OPTARG'" >&2; usage ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
user="$1"
if ! printf '%s' "$user" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}$'; then
  echo "useradd: invalid user name '$user'" >&2; exit 3
fi
case "$comment" in *:*) echo "useradd: invalid comment '$comment'" >&2; exit 3 ;; esac
if cut -d: -f1 "$P" | grep -qx "$user"; then echo "useradd: user '$user' already exists" >&2; exit 9; fi
oldifs="$IFS"; IFS=,
for g in $groups; do
  if ! cut -d: -f1 "$G" | grep -qx "$g"; then echo "useradd: group '$g' does not exist" >&2; exit 6; fi
done
IFS="$oldifs"
if [ -z "$uid" ]; then
  uid="$(awk -F: '$3 >= 1000 && $3 < 60000 && $3 > m { m = $3 } END { print (m ? m + 1 : 1000) }' "$P")"
elif cut -d: -f3 "$P" | grep -qx "$uid"; then
  echo "useradd: UID $uid is not unique" >&2; exit 4
fi
if [ -n "$pgroup" ]; then
  gid="$(awk -F: -v g="$pgroup" '$1 == g || $3 == g { print $3; exit }' "$G")"
  [ -n "$gid" ] || { echo "useradd: group '$pgroup' does not exist" >&2; exit 6; }
else
  if cut -d: -f1 "$G" | grep -qx "$user"; then
    echo "useradd: group $user exists - if you want to add this user to that group, use -g." >&2; exit 9
  fi
  gid="$uid"
  echo "$user:x:$gid:" >> "$G"
fi
[ -n "$home" ] || home="/home/$user"
echo "$user:x:$uid:$gid:$comment:$home:$shell" >> "$P"
if [ -n "$groups" ]; then
  awk -F: -v OFS=: -v u="$user" -v list=",$groups," \
    'index(list, "," $1 ",") { $4 = ($4 == "" ? u : $4 "," u) } { print }' "$G" > "$G.tmp" && mv "$G.tmp" "$G"
fi
if [ "$mkhome" = 1 ]; then
  mkdir -p "$ROOT$home" && cp -R "$ROOT/etc/skel/." "$ROOT$home/"
fi
exit 0
SCRIPT

# ---------------------------------------------------------------- usermod
cat > usermod <<'SCRIPT'
#!/bin/bash
# Mock usermod for LinuxMissions: edits ./etc/passwd and ./etc/group.
# Options: -a -G GROUPS -s SHELL -c COMMENT. Like the real tool, -G without
# -a REPLACES the user's supplementary groups with exactly the list given.
ROOT="$(cd "$(dirname "$0")" && pwd)"; P="$ROOT/etc/passwd"; G="$ROOT/etc/group"
usage() { echo "Usage: usermod [options] LOGIN  (mock: -a -G -s -c)" >&2; exit 2; }
append=0; groups=""; setg=0; shell=""; comment=""; setc=0
args=()
for a in "$@"; do
  case "$a" in
    --append) args+=(-a) ;; --groups) args+=(-G) ;; --shell) args+=(-s) ;; --comment) args+=(-c) ;;
    --groups=*) args+=(-G "${a#*=}") ;; --shell=*) args+=(-s "${a#*=}") ;; --comment=*) args+=(-c "${a#*=}") ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"
while getopts ":aG:s:c:" o; do
  case "$o" in
    a) append=1 ;; G) groups="$OPTARG"; setg=1 ;; s) shell="$OPTARG" ;; c) comment="$OPTARG"; setc=1 ;;
    :) echo "usermod: option requires an argument -- '$OPTARG'" >&2; usage ;;
    *) echo "usermod: invalid option -- '$OPTARG'" >&2; usage ;;
  esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
user="$1"
if [ "$append" = 1 ] && [ "$setg" = 0 ]; then
  echo "usermod: -a flag is ONLY allowed with the -G flag" >&2; usage
fi
if ! cut -d: -f1 "$P" | grep -qx "$user"; then echo "usermod: user '$user' does not exist" >&2; exit 6; fi
oldifs="$IFS"; IFS=,
for g in $groups; do
  if ! cut -d: -f1 "$G" | grep -qx "$g"; then echo "usermod: group '$g' does not exist" >&2; exit 6; fi
done
IFS="$oldifs"
if [ "$setg" = 1 ]; then
  awk -F: -v OFS=: -v u="$user" -v list=",$groups," -v append="$append" '
    {
      n = split($4, m, ","); out = ""; has = 0
      for (i = 1; i <= n; i++) {
        if (m[i] == u) { has = 1; if (!append && !index(list, "," $1 ",")) continue }
        out = (out == "" ? m[i] : out "," m[i])
      }
      if (!has && index(list, "," $1 ",")) out = (out == "" ? u : out "," u)
      $4 = out; print
    }' "$G" > "$G.tmp" && mv "$G.tmp" "$G"
fi
if [ -n "$shell" ] || [ "$setc" = 1 ]; then
  awk -F: -v OFS=: -v u="$user" -v sh="$shell" -v c="$comment" -v setc="$setc" \
    '$1 == u { if (sh != "") $7 = sh; if (setc) $5 = c } { print }' "$P" > "$P.tmp" && mv "$P.tmp" "$P"
fi
exit 0
SCRIPT

# ---------------------------------------------------------------- userdel
cat > userdel <<'SCRIPT'
#!/bin/bash
# Mock userdel for LinuxMissions: -r also removes the home directory.
ROOT="$(cd "$(dirname "$0")" && pwd)"; P="$ROOT/etc/passwd"; G="$ROOT/etc/group"
remove=0
[ "$1" = "-r" ] && { remove=1; shift; }
user="$1"
[ -n "$user" ] || { echo "Usage: userdel [-r] LOGIN" >&2; exit 2; }
line="$(grep "^$user:" "$P")"
[ -n "$line" ] || { echo "userdel: user '$user' does not exist" >&2; exit 6; }
home="$(printf '%s' "$line" | cut -d: -f6)"
grep -v "^$user:" "$P" > "$P.tmp" && mv "$P.tmp" "$P"
awk -F: -v OFS=: -v u="$user" '
  $1 == u { next }
  { n = split($4, m, ","); out = ""; for (i = 1; i <= n; i++) if (m[i] != u) out = (out == "" ? m[i] : out "," m[i]); $4 = out; print }' \
  "$G" > "$G.tmp" && mv "$G.tmp" "$G"
if [ "$remove" = 1 ] && [ -d "$ROOT$home" ] && [ "$home" != "/" ]; then rm -rf "$ROOT$home"; fi
exit 0
SCRIPT

# ---------------------------------------------------------------- id / groups
cat > id <<'SCRIPT'
#!/bin/bash
# Mock id for LinuxMissions: reads ./etc/passwd and ./etc/group.
ROOT="$(cd "$(dirname "$0")" && pwd)"
user="$1"
[ -n "$user" ] || { echo "usage: ./id USER (mock)" >&2; exit 1; }
line="$(grep "^$user:" "$ROOT/etc/passwd")"
[ -n "$line" ] || { echo "id: '$user': no such user" >&2; exit 1; }
uid="$(echo "$line" | cut -d: -f3)"; gid="$(echo "$line" | cut -d: -f4)"
awk -F: -v u="$user" -v uid="$uid" -v gid="$gid" '
  { name[$3] = $1 }
  $3 == gid { prim = $1 }
  { n = split($4, m, ","); for (i = 1; i <= n; i++) if (m[i] == u && $3 != gid) extra = extra "," $3 "(" $1 ")" }
  END { printf "uid=%s(%s) gid=%s(%s) groups=%s(%s)%s\n", uid, u, gid, prim, gid, prim, extra }' "$ROOT/etc/group"
SCRIPT

cat > groups <<'SCRIPT'
#!/bin/bash
# Mock groups for LinuxMissions: reads ./etc/passwd and ./etc/group.
ROOT="$(cd "$(dirname "$0")" && pwd)"
for user in "$@"; do
  line="$(grep "^$user:" "$ROOT/etc/passwd")"
  [ -n "$line" ] || { echo "groups: '$user': no such user" >&2; continue; }
  gid="$(echo "$line" | cut -d: -f4)"
  awk -F: -v u="$user" -v gid="$gid" '
    $3 == gid { prim = $1 }
    { n = split($4, m, ","); for (i = 1; i <= n; i++) if (m[i] == u && $3 != gid) extra = extra " " $1 }
    END { print u " : " prim extra }' "$ROOT/etc/group"
done
SCRIPT

chmod +x useradd usermod userdel id groups
