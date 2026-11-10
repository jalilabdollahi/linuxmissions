#!/bin/bash
# lb.env = original lines + exactly one final BACKENDS= line.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f lb.env ]; then
  echo "❌ lb.env is missing"
  exit 1
fi
count=$(grep -c '^BACKENDS=' lb.env)
if [ "$count" -eq 0 ]; then
  echo "❌ lb.env has no BACKENDS= line yet"
  exit 1
fi
if [ "$count" -gt 1 ]; then
  echo "❌ lb.env has $count BACKENDS= lines, expected exactly one"
  exit 1
fi
orig_n=$(wc -l < .lm-state/lb.env.orig)
if ! head -n "$orig_n" lb.env | cmp -s - .lm-state/lb.env.orig; then
  echo "❌ the existing lines of lb.env were changed or removed: only append the new line"
  exit 1
fi
if [ "$(wc -l < lb.env)" -ne $((orig_n + 1)) ] || ! tail -n 1 lb.env | grep -q '^BACKENDS='; then
  echo "❌ lb.env must end with the BACKENDS= line, with nothing after it (found $(wc -l < lb.env | tr -d ' ') lines, expected $((orig_n + 1)))"
  exit 1
fi
got=$(tail -n 1 lb.env | tr -d '\r')
want=$(cat .lm-state/want-line)
if [ "$got" = "$want" ]; then
  echo "✅ lb.env ends with $(echo "$want" | tr ',' '\n' | wc -l | tr -d ' ') backends on one BACKENDS line"
  exit 0
fi
case "$got" in
  *:,*|*:) echo "❌ the BACKENDS line contains an entry with an empty port: look for a blank line in one of the input files" ;;
  *", "*|*" "*) echo "❌ the BACKENDS line contains spaces: entries are separated by commas only" ;;
  *) echo "❌ the BACKENDS line does not match hosts.txt and ports.txt (expected host:port pairs, comma separated, in order)" ;;
esac
exit 1
