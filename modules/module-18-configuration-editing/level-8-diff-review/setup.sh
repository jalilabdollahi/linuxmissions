#!/bin/bash
# Reformatted and Tweaked: the old file is tab indented with aligned columns, the new
# one uses 4 spaces, collapsed alignment and extra blank lines, so plain diff reports
# almost every line. Three directives truly changed: maxconn (2000 -> 200, in the
# global section), balance and retries. Directive names are unique per file so
# "which settings changed" has a clean answer.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

# Build the old file with tabs and aligned columns.
{
  printf 'global\n'
  printf '\tlog\t\t/dev/log local0\n'
  printf '\tmaxconn\t\t2000\n'
  printf '\tuser\t\thaproxy\n'
  printf '\tgroup\t\thaproxy\n'
  printf '\tdaemon\n\n'
  printf 'defaults\n'
  printf '\tmode\t\thttp\n'
  printf '\tretries\t\t3\n'
  printf '\ttimeout\t\tclient 30s\n'
  printf '\toption\t\thttplog\n\n'
  printf 'frontend public\n'
  printf '\tbind\t\t*:80\n'
  printf '\tacl\t\tis_api path_beg /api\n'
  printf '\tdefault_backend\tapp\n\n'
  printf 'backend app\n'
  printf '\tbalance\t\troundrobin\n'
  printf '\toption\t\thttpchk GET /health\n'
  for i in $(seq 1 40); do
    printf '\tserver\t\tapp%02d 10.0.%d.%d:8080 check inter 2s rise 3 fall 2\n' "$i" $((i / 20 + 1)) $((i + 10))
  done
} > haproxy.orig.cfg

# New file: spaces instead of tabs, collapsed alignment, blank lines between
# lines of a section, and the three real changes.
sed -e 's/^\t/    /' -e 's/\t\+/ /g' \
    -e 's/^\(    maxconn\) 2000$/\1 200/' \
    -e 's/^\(    retries\) 3$/\1 5/' \
    -e 's/^\(    balance\) roundrobin$/\1 leastconn/' \
    haproxy.orig.cfg | awk '{ print } NR % 7 == 0 { print "" }' > haproxy.cfg

cksum haproxy.orig.cfg haproxy.cfg > .lm-state/inputs
printf '%s\n' balance maxconn retries > .lm-state/want
