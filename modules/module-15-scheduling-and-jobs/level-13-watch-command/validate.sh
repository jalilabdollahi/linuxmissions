#!/bin/bash
# Compares the moment spool/ became empty (written by the uploader) with the
# first call of switch-traffic.sh: not before, at most 5 seconds after.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

entries() { ls -A spool 2>/dev/null | wc -l | tr -d ' '; }
first_switch=""
[ -s .lm/switch-at ] && read -r first_switch left_at_switch < .lm/switch-at

if [ ! -s .lm/drained-at ]; then
  if [ -n "$first_switch" ]; then
    echo "❌ traffic was switched while $left_at_switch entries were still in spool/; type reset to refill the queue and try again"
  elif [ -f .lm/uploader.pid ] && kill -0 "$(cat .lm/uploader.pid)" 2>/dev/null; then
    echo "❌ the queue is still draining ($(entries) entries left in spool/)"
  else
    echo "❌ the uploader is paused: spool/ still holds $(entries) entries"
  fi
  exit 1
fi

read -r drained < .lm/drained-at
if [ -z "$first_switch" ]; then
  late=$(awk -v d="$drained" -v n="$(date +%s.%N)" 'BEGIN { printf "%d", n - d }')
  if [ "$late" -gt 5 ]; then
    echo "❌ spool/ has been empty for ${late}s and traffic is still not switched; type reset to refill the queue and try again"
  else
    echo "❌ spool/ is empty but traffic has not been switched yet"
  fi
  exit 1
fi

verdict=$(awk -v d="$drained" -v s="$first_switch" 'BEGIN {
  diff = s - d
  if (diff < 0) printf "early %.1f", -diff
  else if (diff > 5) printf "late %.1f", diff
  else printf "ok %.1f", diff }')
set -- $verdict
case "$1" in
  early)
    echo "❌ traffic was switched $2s before spool/ was empty ($left_at_switch entries were still there); type reset to refill the queue and try again"
    exit 1 ;;
  late)
    echo "❌ traffic was switched $2s after spool/ became empty; the load balancer allows 5s. Type reset to refill the queue and try again"
    exit 1 ;;
esac

echo "✅ traffic switched $2s after the last upload left spool/"
exit 0
