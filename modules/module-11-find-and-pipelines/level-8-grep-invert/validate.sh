#!/bin/bash
# effective.conf = the non-comment, non-blank lines of postgresql.conf, unchanged, in order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/effective ] || [ ! -s .lm-state/conf.sum ]; then
  echo "❌ the level's reference data in .lm-state/ is gone; type 'reset'"
  exit 1
fi
if [ ! -f postgresql.conf ] || [ "$(cksum < postgresql.conf)" != "$(cat .lm-state/conf.sum)" ]; then
  echo "❌ postgresql.conf was changed or removed; it must stay as it is (type 'reset')"
  exit 1
fi
if [ ! -f effective.conf ]; then
  echo "❌ effective.conf does not exist yet"
  exit 1
fi
if cmp -s effective.conf .lm-state/effective; then
  echo "✅ effective.conf holds the $(wc -l < .lm-state/effective | tr -d ' ') settings that are really in effect, nothing else"
  exit 0
fi
if [ ! -s effective.conf ]; then
  echo "❌ effective.conf is empty"
  exit 1
fi
c=$(grep -c '^[[:space:]]*#' effective.conf)
if [ "$c" -gt 0 ]; then
  echo "❌ effective.conf still has $c comment line(s), e.g.: $(grep -m1 '^[[:space:]]*#' effective.conf | sed 's/\t/<TAB>/g')"
  exit 1
fi
b=$(grep -c '^[[:space:]]*$' effective.conf)
if [ "$b" -gt 0 ]; then
  echo "❌ effective.conf still has $b empty or whitespace-only line(s)"
  exit 1
fi
want=$(wc -l < .lm-state/effective | tr -d ' ')
got=$(wc -l < effective.conf | tr -d ' ')
if [ "$got" -lt "$want" ]; then
  missing=$(grep -vxF -f effective.conf .lm-state/effective | head -1)
  case $missing in
    *'#'*) echo "❌ effective.conf has $got of the $want settings; a setting with a # comment after its value is still a setting" ;;
    *)     echo "❌ effective.conf has $got of the $want settings; missing for example: $missing" ;;
  esac
  exit 1
fi
if [ "$(LC_ALL=C sort effective.conf)" = "$(LC_ALL=C sort .lm-state/effective)" ]; then
  echo "❌ effective.conf has the right lines but not in the order of postgresql.conf"
  exit 1
fi
bad=$(grep -vxF -f .lm-state/effective effective.conf | head -1)
echo "❌ effective.conf has a line that is not exactly as in postgresql.conf: $bad"
exit 1
