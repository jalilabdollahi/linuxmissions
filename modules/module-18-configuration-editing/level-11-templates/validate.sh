#!/bin/bash
# out/<env>.conf must equal the exact render for each of the four environments.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if ! cmp -s envs.csv .lm-state/envs.csv || ! cmp -s app.conf.tmpl .lm-state/app.conf.tmpl; then
  echo "❌ envs.csv or app.conf.tmpl was modified; they are the inputs, type 'reset' to restore them"
  exit 1
fi
if [ ! -d out ]; then
  echo "❌ the directory out/ does not exist yet"
  exit 1
fi
for env in dev staging prod dr; do
  f=out/$env.conf
  if [ ! -f "$f" ]; then
    echo "❌ $f does not exist yet"
    exit 1
  fi
  if cmp -s "$f" ".lm-state/expected/$env.conf"; then
    continue
  fi
  if [ ! -s "$f" ]; then
    echo "❌ $f is empty: the command that wrote it failed (a value probably broke it)"
  elif grep -q '{{' "$f"; then
    echo "❌ $f still contains an unreplaced {{placeholder}}"
  elif [ "$env" = prod ] && ! grep -qF 'sslmode=require&pool=40' "$f"; then
    echo "❌ $f has a damaged DB URL: the '&' and '/' of the value must come out unchanged"
  elif [ "$env" = dr ] && ! grep -qF 'password = a|b&c\d' "$f"; then
    echo "❌ $f has a damaged password: '|', '&' and '\\' in a value must be copied literally"
  elif [ "$(wc -l < "$f")" != "$(wc -l < ".lm-state/expected/$env.conf")" ]; then
    echo "❌ $f has $(wc -l < "$f" | tr -d ' ') lines, expected $(wc -l < ".lm-state/expected/$env.conf" | tr -d ' ')"
  else
    echo "❌ $f does not match the template rendered with the $env row ($(diff "$f" ".lm-state/expected/$env.conf" | grep -c '^<') line(s) differ)"
  fi
  exit 1
done
if [ "$(ls out | wc -l)" != 4 ]; then
  echo "❌ out/ should hold exactly four files, found $(ls out | wc -l | tr -d ' ')"
  exit 1
fi
echo "✅ four environment configs rendered exactly, special characters included"
exit 0
