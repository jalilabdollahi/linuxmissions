#!/bin/bash
# Builds three fixtures with different TODAY values, computes the expected keep set
# with a reference implementation, and checks dry run, --apply and bad arguments.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f prune.sh ] || { echo "❌ prune.sh is missing"; exit 1; }
W=$(mktemp -d "$SANDBOX/.lm-state/val.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/run"

dn() { echo $(( $(date -u -d "$1" +%s) / 86400 )); }

# reference: prints "NAME reason" for every kept valid backup, given TODAY and a directory
reference() {
  local today=$1 dir=$2 t s0 first f d n k
  t=$(dn "$today")
  s0=$(( t - $(date -u -d "$today" +%u) % 7 ))
  first=$(dn "$(date -u -d "$(date -u -d "$today" +%Y-%m-01) -11 months" +%F)")
  declare -A bestn bestf
  for f in "$dir"/db-*.tar.zst; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    f=$(basename "$f")
    [[ $f =~ ^db-([0-9]{4}-[0-9]{2}-[0-9]{2})\.tar\.zst$ ]] || continue
    d=${BASH_REMATCH[1]}
    [ "$(date -u -d "$d" +%F 2>/dev/null)" = "$d" ] || continue
    n=$(dn "$d")
    if [ "$n" -gt "$t" ]; then echo "$f future"; continue; fi
    [ $((t - n)) -le 6 ] && echo "$f daily"
    [ "${d:8:2}" = 01 ] && [ "$n" -ge "$first" ] && echo "$f monthly"
    if [ "$n" -le "$s0" ] && [ $((s0 - n)) -lt 28 ]; then
      k=$(( (s0 - n) / 7 ))
      if [ -z "${bestn[$k]}" ] || [ "$n" -gt "${bestn[$k]}" ]; then bestn[$k]=$n; bestf[$k]=$f; fi
    fi
  done
  for k in "${!bestf[@]}"; do echo "${bestf[$k]} weekly"; done
}
# a monthly/daily backup may also be the newest of its week: reference prints it once; weekly winners that
# were already kept by another rule are printed twice, so deduplicate
valid_names() {
  for f in "$1"/db-*.tar.zst; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    f=$(basename "$f"); [[ $f =~ ^db-([0-9]{4}-[0-9]{2}-[0-9]{2})\.tar\.zst$ ]] || continue
    [ "$(date -u -d "${BASH_REMATCH[1]}" +%F 2>/dev/null)" = "${BASH_REMATCH[1]}" ] && echo "$f"
  done | LC_ALL=C sort
}

fixture() {  # dir today missing-sunday-percent seed
  local dir=$1 today=$2 skip=$3 i d dow dom
  rm -rf "$dir"; mkdir -p "$dir/backups"
  for i in $(seq 0 440); do
    d=$(date -u -d "$today - $i days" +%F); dow=$(date -u -d "$d" +%u); dom=${d:8:2}
    if [ "$i" -lt 9 ] || [ "$dow" = 7 ] || [ "$dom" = 01 ] || [ $((RANDOM % 7)) = 0 ]; then
      if [ "$i" -gt 6 ] && { [ "$dow" = 7 ] && [ $((RANDOM % 100)) -lt "$skip" ] || [ "$dom" = 01 ] && [ $((RANDOM % 100)) -lt "$skip" ]; }; then continue; fi
      : > "$dir/backups/db-$d.tar.zst"
    fi
  done
  : > "$dir/backups/db-$(date -u -d "$today + 3 days" +%F).tar.zst"
  : > "$dir/backups/db-2026-13-40.tar.zst"; : > "$dir/backups/db-2025-02-30.tar.zst"
  : > "$dir/backups/db-2026-1-5.tar.zst"; : > "$dir/backups/db-final.tar.zst"
  : > "$dir/backups/db-2026-03-03.tar.zst.partial"; : > "$dir/backups/notes.txt"
  ln -s "db-$today.tar.zst" "$dir/backups/db-latest.tar.zst"
  cp "$SANDBOX/prune.sh" "$dir/prune.sh"
}

# argument handling first
fixture "$W/fx0" 2026-11-10 20
before=$(ls -A "$W/fx0/backups" | LC_ALL=C sort | sha256sum)
( cd "$W/run" && TODAY=2026-11-10 timeout 10 bash "$W/fx0/prune.sh" --bogus >/dev/null 2>&1 ); code=$?
if [ "$code" -eq 0 ] || [ "$(ls -A "$W/fx0/backups" | LC_ALL=C sort | sha256sum)" != "$before" ]; then
  echo "❌ an unknown argument (--bogus) must print a usage line, exit non-zero (2) and delete nothing"
  exit 1
fi

n=0
for sc in "2026-11-10 15" "2026-01-03 40" "2024-03-02 25"; do
  set -- $sc; today=$1; skip=$2; n=$((n + 1)); dir="$W/fx$n"
  fixture "$dir" "$today" "$skip"
  ref=$(reference "$today" "$dir/backups" | awk '{print $1}' | LC_ALL=C sort -u)
  all=$(valid_names "$dir/backups")
  del=$(comm -23 <(printf '%s\n' "$all") <(printf '%s\n' "$ref"))
  snapshot=$(cd "$dir/backups" && ls -A | LC_ALL=C sort | tr '\n' ' ')
  # dry run
  out=$(cd "$W/run" && TODAY=$today timeout 10 bash "$dir/prune.sh" 2>"$W/err"); code=$?
  [ "$code" -eq 0 ] || { echo "❌ with TODAY=$today the dry run exits with status $code ($(head -c 150 "$W/err"))"; exit 1; }
  if [ "$(cd "$dir/backups" && ls -A | LC_ALL=C sort | tr '\n' ' ')" != "$snapshot" ]; then
    echo "❌ with TODAY=$today the dry run (no --apply) deleted or changed something in backups/"; exit 1
  fi
  said=$(printf '%s\n' "$out" | sed -n 's/^would delete //p' | LC_ALL=C sort -u)
  if [ "$said" != "$del" ]; then
    x=$(comm -23 <(printf '%s\n' "$said") <(printf '%s\n' "$del") | head -1); y=$(comm -13 <(printf '%s\n' "$said") <(printf '%s\n' "$del") | head -1)
    if [ -n "$x" ]; then echo "❌ TODAY=$today: the dry run says it would delete $x, which the policy keeps"
    else echo "❌ TODAY=$today: the dry run does not list $y, which the policy deletes (print one 'would delete NAME' line per file)"; fi
    exit 1
  fi
  # apply
  ( cd "$W/run" && TODAY=$today timeout 10 bash "$dir/prune.sh" --apply >/dev/null 2>&1 ); code=$?
  [ "$code" -eq 0 ] || { echo "❌ TODAY=$today: --apply exits with status $code"; exit 1; }
  left=$(valid_names "$dir/backups")
  if [ "$left" != "$ref" ]; then
    x=$(comm -23 <(printf '%s\n' "$left") <(printf '%s\n' "$ref") | head -1); y=$(comm -13 <(printf '%s\n' "$left") <(printf '%s\n' "$ref") | head -1)
    if [ -n "$y" ]; then
      reason=$(reference "$today" "$dir/backups" | awk -v f="$y" '$1==f {print $2; exit}')
      echo "❌ TODAY=$today: --apply deleted $y, which the policy keeps (${reason:-weekly} rule; a week is Monday to Sunday, the newest backup of it stays)"
    else
      echo "❌ TODAY=$today: --apply left $x in place, but it is outside daily, weekly, monthly retention"
    fi
    exit 1
  fi
  for f in db-2026-13-40.tar.zst db-2025-02-30.tar.zst db-2026-1-5.tar.zst db-final.tar.zst db-2026-03-03.tar.zst.partial notes.txt; do
    [ -e "$dir/backups/$f" ] || { echo "❌ TODAY=$today: $f is not a valid backup name and must never be deleted"; exit 1; }
  done
  if [ ! -L "$dir/backups/db-latest.tar.zst" ] || [ "$(readlink "$dir/backups/db-latest.tar.zst")" != "db-$today.tar.zst" ]; then
    echo "❌ TODAY=$today: the db-latest.tar.zst symlink must be left alone"; exit 1
  fi
  fut="db-$(date -u -d "$today + 3 days" +%F).tar.zst"
  [ -e "$dir/backups/$fut" ] || { echo "❌ TODAY=$today: $fut is dated after TODAY and must be kept"; exit 1; }
done
echo "✅ prune.sh keeps exactly the daily, weekly and monthly backups for three different dates, is a dry run by default and ignores files that are not backups"
