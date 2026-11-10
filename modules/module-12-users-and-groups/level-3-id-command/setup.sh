#!/bin/bash
# Permission Denied on One Host: `id deploy` captured on five hosts with an
# ansible ad-hoc run. Which host gets which group set is random. Traps: on one
# host www-data is deploy's PRIMARY group (gid=33), which still counts; one host
# has the look-alike www-data-ro; another a group simply called www.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

hosts=(web-01 web-02 web-03 api-01 api-02)
# Variants: a = www-data supplementary, e = www-data last in the list,
# b = www-data is the primary group, c = only www-data-ro, d = no web group,
# w = a group named "www". b and c are always used, plus three of a/e/d/w.
order=$(awk -v seed="$RANDOM" 'BEGIN {
  srand(seed)
  n = split("a e d w", x, " ")
  for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = x[i]; x[i] = x[j]; x[j] = t }
  v[1] = "b"; v[2] = "c"; v[3] = x[1]; v[4] = x[2]; v[5] = x[3]
  for (i = 5; i > 1; i--) { j = int(rand() * i) + 1; t = v[i]; v[i] = v[j]; v[j] = t }
  for (i = 1; i <= 5; i++) print v[i]
}')

k=0
for v in $order; do
  h=${hosts[$k]}; k=$((k + 1))
  u=$((1001 + RANDOM % 6))
  dk=$((990 + RANDOM % 9))
  case $v in
    a) line="uid=$u(deploy) gid=$u(deploy) groups=$u(deploy),4(adm),33(www-data),$dk(docker)" ;;
    e) line="uid=$u(deploy) gid=$u(deploy) groups=$u(deploy),$dk(docker),1010(releases),33(www-data)" ;;
    b) line="uid=$u(deploy) gid=33(www-data) groups=33(www-data),4(adm),$dk(docker)" ;;
    c) line="uid=$u(deploy) gid=$u(deploy) groups=$u(deploy),4(adm),1012(www-data-ro),$dk(docker)" ;;
    d) line="uid=$u(deploy) gid=$u(deploy) groups=$u(deploy),4(adm),27(sudo),$dk(docker)" ;;
    w) line="uid=$u(deploy) gid=$u(deploy) groups=$u(deploy),1020(www),$dk(docker)" ;;
  esac
  printf '%s | CHANGED | rc=0 >>\n%s\n' "$h" "$line" > "id-$h.txt"
done
