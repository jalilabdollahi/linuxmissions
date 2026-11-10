#!/bin/bash
# Reference solution: put a DEBUG block right after the shebang that sends
# xtrace with a file:line PS4 to trace.log through BASH_XTRACEFD, read the
# trace, then quote the right side of the [[ == ]] that compares names.
{
  head -n 1 invoice_sync.sh
  cat <<'DBG'
if [ "${DEBUG:-}" = 1 ]; then
  exec 9> trace.log
  BASH_XTRACEFD=9
  PS4='+${BASH_SOURCE}:${LINENO}: '
  set -x
fi
DBG
  tail -n +2 invoice_sync.sh
} > invoice_sync.new && mv invoice_sync.new invoice_sync.sh && chmod +x invoice_sync.sh

DEBUG=1 ./invoice_sync.sh > /dev/null 2>&1
grep -F 'E*Trade' trace.log | grep -F '[[' | head -3

sed 's/\[\[ \$1 == \$2 \]\]/[[ $1 == "$2" ]]/' invoice_sync.sh > invoice_sync.new &&
  mv invoice_sync.new invoice_sync.sh && chmod +x invoice_sync.sh
./invoice_sync.sh
