#!/bin/bash
# 1) data/ here is in the expected end state and retention.log is exactly the expected actions
# 2) a second run changes nothing and logs nothing
# 3) the same script on a pristine copy gives the same result (so it is a real script)
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f retention.sh ] || { echo "❌ retention.sh does not exist yet"; exit 1; }
state() {  # dir
  ( cd "$1" && find data -type f -print0 | while IFS= read -r -d '' p; do
      case "$p" in
        *.gz) h=$(gunzip -c "$p" 2>/dev/null | sha256sum | cut -d' ' -f1) ;;
        *) h=$(sha256sum < "$p" | cut -d' ' -f1) ;;
      esac
      printf '%s\t%s\t%s\n' "$p" "$(stat -c %Y "$p")" "$h"
    done | LC_ALL=C sort )
}
explain() {  # dir  (compare state to expect, print the first problem)
  local got want
  got=$(state "$1"); want=$(cat .lm-state/expect.tsv)
  [ "$got" = "$want" ] && return 0
  local x y
  x=$(comm -23 <(cut -f1 <<< "$got" | LC_ALL=C sort) <(cut -f1 .lm-state/expect.tsv | LC_ALL=C sort) | head -1)
  y=$(comm -13 <(cut -f1 <<< "$got" | LC_ALL=C sort) <(cut -f1 .lm-state/expect.tsv | LC_ALL=C sort) | head -1)
  if [ -n "$x" ]; then
    case "$x" in
      *.gz.gz) echo "❌ $x: an already compressed log was compressed again" ;;
      *.log) echo "❌ $x is still there but the policy says it must be compressed or deleted" ;;
      *pii-*) echo "❌ $x is still there but it is a PII export past 30 days with no legal hold" ;;
      *.pdf) echo "❌ $x is older than 7 years and should have been deleted" ;;
      *.gz) echo "❌ $x is still there but it is older than 90 days, or is an unexpected extra file" ;;
      *) echo "❌ unexpected file $x (not covered by the policy, or a leftover of your script)" ;;
    esac
  elif [ -n "$y" ]; then
    case "$y" in
      *pii-*) echo "❌ $y was deleted but it is on legal hold or younger than 30 days" ;;
      *.gz) echo "❌ $y is missing: logs between 7 and 90 days old must be compressed (not deleted), with the .gz name" ;;
      *.pdf) echo "❌ $y was deleted but invoices are kept for 7 years" ;;
      *) echo "❌ $y was deleted but the policy does not cover it" ;;
    esac
  else
    d=$(comm -3 <(printf '%s\n' "$got") .lm-state/expect.tsv | head -1 | cut -f1)
    case "$d" in
      *.gz) echo "❌ $d has the wrong modification time or content: the compressed log must keep the original's modification time" ;;
      *) echo "❌ $d was modified (content or modification time): only compress and delete" ;;
    esac
  fi
  return 1
}
logcheck() {  # logfile  expected-count-label
  local f=$1
  [ -f "$f" ] || { echo "❌ retention.log is missing: the script has to log every action"; return 1; }
  local dup; dup=$(LC_ALL=C sort "$f" | uniq -d | head -1)
  [ -z "$dup" ] || { echo "❌ retention.log lists '$dup' more than once"; return 1; }
  if [ "$(LC_ALL=C sort "$f")" != "$(cat .lm-state/actions)" ]; then
    local a b
    a=$(comm -23 <(LC_ALL=C sort "$f") .lm-state/actions | head -1); b=$(comm -13 <(LC_ALL=C sort "$f") .lm-state/actions | head -1)
    if [ -n "$a" ]; then echo "❌ retention.log has the line '$a', which is not an action the policy requires (format: COMPRESS|DELETE path)"
    else echo "❌ retention.log has no line '$b'"; fi
    return 1
  fi
  return 0
}

explain . || exit 1
logcheck retention.log || exit 1

# second run in place
cp retention.log .lm-state/log.before; s_before=$(state .)
( cd / && timeout 20 bash "$SANDBOX/retention.sh" >/dev/null 2>&1 )
if [ "$(state .)" != "$s_before" ] || ! cmp -s retention.log .lm-state/log.before; then
  echo "❌ running retention.sh a second time changed something (files or log): it must be idempotent"
  exit 1
fi

# pristine copy
W=$(mktemp -d "$SANDBOX/.lm-state/val.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/fx" "$W/run"
tar -xf .lm-state/orig.tar -C "$W/fx"
cp retention.sh "$W/fx/"
( cd "$W/run" && timeout 20 bash "$W/fx/retention.sh" >/dev/null 2>&1 ); code=$?
[ "$code" -eq 0 ] || { echo "❌ on a fresh copy of the data retention.sh exits with status $code"; exit 1; }
if [ "$(state "$W/fx")" != "$(cat .lm-state/expect.tsv)" ]; then
  echo "❌ the script gives a different result on a fresh copy of the data than the state here: it must do the whole job itself (use only data/ next to the script, no hand-picked names)"
  exit 1
fi
if [ ! -f "$W/fx/retention.log" ] || [ "$(LC_ALL=C sort "$W/fx/retention.log")" != "$(cat .lm-state/actions)" ]; then
  echo "❌ on a fresh copy of the data the log of the script is not exactly the list of actions (each action once, 'COMPRESS path' or 'DELETE path')"
  exit 1
fi
echo "✅ the policy is applied exactly, every action is logged once, and a second run does nothing"
