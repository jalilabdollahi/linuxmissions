#!/bin/bash
# Capital X. A config tree with group/other write everywhere. Directories,
# scripts (any file with an x bit) and data files get random loose modes that
# all keep owner rw(x) and group r(x), so the expected result is a clean
# table: dirs 755, executables 755, data 644. A script-looking name without
# an x bit (run-me.txt) and dotfiles are included so that `chmod -R +x`
# or `a+rx` is caught.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p etc-app/conf.d etc-app/hooks etc-app/tls etc-app/templates/mail .lm-state
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
dirs=(etc-app etc-app/conf.d etc-app/hooks etc-app/tls etc-app/templates etc-app/templates/mail)
data=(etc-app/app.conf etc-app/conf.d/10-db.conf etc-app/conf.d/20-cache.conf etc-app/conf.d/99-local.conf
      etc-app/.env etc-app/tls/ca.pem etc-app/tls/server.crt etc-app/templates/welcome.tmpl
      etc-app/templates/mail/reset.tmpl etc-app/hooks/README.txt etc-app/hooks/run-me.txt)
exes=(etc-app/hooks/pre-start.sh etc-app/hooks/post-stop.sh etc-app/hooks/check-config etc-app/tls/renew.sh)

: > .lm-state/expected
for d in "${dirs[@]}"; do
  chmod "$(pick 775 777 757 775)" "$d"
  printf '%s\t755\n' "$d" >> .lm-state/expected
done
for f in "${data[@]}"; do
  printf 'setting=%s\n' "$RANDOM" > "$f"
  chmod "$(pick 664 666 660 664 644)" "$f"
  printf '%s\t644\n' "$f" >> .lm-state/expected
done
for f in "${exes[@]}"; do
  printf '#!/bin/sh\necho "%s ok"\n' "${f##*/}" > "$f"
  chmod "$(pick 775 777 775 770 774)" "$f"
  printf '%s\t755\n' "$f" >> .lm-state/expected
done
find etc-app -type f | LC_ALL=C sort | xargs cksum > .lm-state/sums
