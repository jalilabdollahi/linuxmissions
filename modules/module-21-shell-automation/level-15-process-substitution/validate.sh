#!/bin/bash
# Runs stale_accounts.sh on the shipped pair of files and on a generated pair,
# from a read-only directory with an unwritable TMPDIR, and compares stdout
# with the list computed here. The script must feed comm or its loop with
# process substitution instead of temp files.
SANDBOX="$1"
SCRIPT="$SANDBOX/stale_accounts.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ stale_accounts.sh is missing (type reset to get it back)"
  exit 1
fi
for f in users.export hr_roster.csv; do
  [ -f "$SANDBOX/$f" ] || { echo "❌ $f is missing (type reset)"; exit 1; }
done

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

code_only="$(sed 's/#.*//' "$SCRIPT")"
if ! printf '%s\n' "$code_only" | grep -q '<('; then
  echo "❌ stale_accounts.sh does not use process substitution <( ... ) yet"
  exit 1
fi
if printf '%s\n' "$code_only" | grep -Eq 'mktemp|/tmp|/dev/shm'; then
  echo "❌ stale_accounts.sh still creates temp files (mktemp or /tmp); the audit runner has nowhere to write them"
  exit 1
fi

# expected EXPORT ROSTER: the right answer
expected() {
  awk -F: '$2 >= 1000 && $2 < 60000 { print $1 }' "$1" | LC_ALL=C sort > "$WORK/sys"
  awk -F, 'NR > 1 && ($3 == "active" || $3 == "leave") { print tolower($2) }' "$2" | LC_ALL=C sort -u > "$WORK/keep"
  LC_ALL=C comm -23 "$WORK/sys" "$WORK/keep" > "$WORK/stale"
  cat "$WORK/stale"
  echo "TOTAL $(wc -l < "$WORK/stale" | tr -d ' ')"
}

# check DIR LABEL: DIR holds users.export and hr_roster.csv
check() {
  want="$(expected "$1/users.export" "$1/hr_roster.csv")"
  mkdir -p "$1/tmp"
  cp "$SCRIPT" "$1/stale_accounts.sh"
  chmod a-w "$1/tmp" "$1"
  (cd "$1" && $LIMIT env TMPDIR="$1/tmp" LC_ALL=C bash ./stale_accounts.sh users.export hr_roster.csv \
     </dev/null >"$WORK/out" 2>"$WORK/err")
  code=$?
  chmod u+w "$1" "$1/tmp"
  got="$(cat "$WORK/out")"
  if [ "$got" = "$want" ] && [ "$code" = 0 ]; then
    return 0
  fi
  if [ -s "$WORK/err" ] && grep -qiE 'denied|read-only|mktemp|cannot create' "$WORK/err"; then
    echo "❌ on $2 the script tried to write a file: $(head -1 "$WORK/err")"
  elif [ "$code" != 0 ]; then
    echo "❌ on $2 stale_accounts.sh exited with status $code: $(head -1 "$WORK/err")"
  elif [ "$(printf '%s\n' "$got" | sed '$d')" = "$(printf '%s\n' "$want" | sed '$d')" ]; then
    echo "❌ on $2 the list is right but the last line is '$(printf '%s\n' "$got" | tail -1)', expected '$(printf '%s\n' "$want" | tail -1)'"
  elif printf '%s\n' "$got" | grep -qxE 'root|daemon|nobody|www-data|backup|deploy|sshd'; then
    echo "❌ on $2 the list contains system accounts (uid below 1000, or nobody)"
  else
    n="$(printf '%s\n' "$want" | sed '$d' | grep -c .)"
    echo "❌ on $2 the list is wrong: expected $n account(s) to disable, got $(printf '%s\n' "$got" | sed '$d' | grep -c .) line(s) before TOTAL"
  fi
  exit 1
}

mkdir -p "$WORK/shipped"
cp "$SANDBOX/users.export" "$SANDBOX/hr_roster.csv" "$WORK/shipped/"
check "$WORK/shipped" "the shipped files"

# A second server and roster, generated.
D="$WORK/second"
mkdir -p "$D"
{
  echo "root:0"; echo "sshd:105"; echo "postgres:112"; echo "nobody:65534"
  echo "svc-backup:$(( 900 + RANDOM % 90 ))"
} > "$D/users.export"
echo "employee_id,login,status,full_name" > "$D/hr_roster.csv"
uid=2000; emp=500
for login in anna.berg bo.li carla dmitri eun.ji farid gwen hugo ines jonas kai lena milo nadia omar petra; do
  uid=$(( uid + 1 + RANDOM % 5 )); emp=$(( emp + 1 ))
  echo "$login:$uid" >> "$D/users.export"
  case $(( RANDOM % 6 )) in
    0) : ;;                                                         # no HR row
    1) echo "E$emp,$(echo "$login" | tr a-z A-Z),terminated,\"Doe, $login\"" >> "$D/hr_roster.csv" ;;
    2) echo "E$emp,$(echo "$login" | tr a-z A-Z),leave,$login" >> "$D/hr_roster.csv" ;;
    *) echo "E$emp,$(echo "$login" | tr a-z A-Z),active,$login" >> "$D/hr_roster.csv" ;;
  esac
done
echo "E900,ZED.GHOST,active,Former contractor" >> "$D/hr_roster.csv"     # HR row without account
echo "quentin:3999" >> "$D/users.export"                                 # account without HR row
check "$D" "a second export and roster"

echo "✅ stale_accounts.sh finds the right accounts and counts them, without a single temp file"
exit 0
