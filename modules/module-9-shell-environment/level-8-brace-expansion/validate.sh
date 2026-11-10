#!/bin/bash
# data/ and svc/ must contain exactly the requested directory tree, and
# config.yaml.bak must be identical to the untouched config.yaml.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

WANT="$(mktemp)"; GOT="$(mktemp)"
trap 'rm -f "$WANT" "$GOT"' EXIT
{
  echo data; echo data/2026
  for m in 01 02 03 04 05 06 07 08 09 10 11 12; do echo "data/2026/$m"; done
  echo svc
  for c in api web worker; do
    echo "svc/$c"
    for s in dev prod; do
      echo "svc/$c/$s"; echo "svc/$c/$s/conf"; echo "svc/$c/$s/logs"
    done
  done
} | LC_ALL=C sort > "$WANT"

if [ ! -d data ] && [ ! -d svc ]; then
  echo "❌ neither data/ nor svc/ exists yet"
  exit 1
fi
find data svc -type d 2>/dev/null | LC_ALL=C sort > "$GOT"

extra="$(LC_ALL=C comm -13 "$WANT" "$GOT" | head -1)"
if [ -n "$extra" ]; then
  case "$extra" in
    *'{'*|*'}'*) echo "❌ there is a directory literally named '$extra': braces inside quotes are not expanded" ;;
    data/2026/[1-9]) echo "❌ $extra is not zero-padded; the months must be 01 to 12 ({1..12} gives 1, 2, ...)" ;;
    *) echo "❌ $extra should not exist; data/ and svc/ must hold only the listed directories" ;;
  esac
  exit 1
fi
missing="$(LC_ALL=C comm -23 "$WANT" "$GOT")"
if [ -n "$missing" ]; then
  echo "❌ $(printf '%s\n' "$missing" | wc -l | tr -d ' ') directories are still missing, for example $(printf '%s\n' "$missing" | head -1)"
  exit 1
fi
stray="$(find data svc ! -type d | head -1)"
if [ -n "$stray" ]; then
  echo "❌ $stray is not a directory; data/ and svc/ should hold only directories for now"
  exit 1
fi

if [ "$(cksum < config.yaml 2>/dev/null)" != "1267846630 284" ]; then
  echo "❌ config.yaml was changed or removed; the backup must come first (type reset to restore it)"
  exit 1
fi
if [ ! -f config.yaml.bak ]; then
  echo "❌ config.yaml.bak does not exist yet"
  exit 1
fi
if ! cmp -s config.yaml config.yaml.bak; then
  echo "❌ config.yaml.bak is not an identical copy of config.yaml"
  exit 1
fi

echo "✅ 12 month directories, 12 conf/logs pairs and an identical config.yaml.bak"
exit 0
