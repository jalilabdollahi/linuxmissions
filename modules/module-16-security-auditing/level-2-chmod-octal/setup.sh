#!/bin/bash
# Never Loosen. ~16 files under app/ with random modes. Policy: files at most
# 640, scripts in app/bin at most 750. Expected = old & mask, so already
# stricter files (600, 400, 440, 700 in bin) must stay as they are.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p app/bin app/conf app/data/exports .lm-state

cat > policy.txt <<'POL'
SECURITY POLICY 7.2 - file permissions under app/

  * No regular file under app/ may grant more than mode 640.
  * Scripts in app/bin/ may grant at most mode 750.
  * A file that is already stricter than the policy must NOT be loosened.
  * Folders are not covered by this change.
POL

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
cfg_modes=(644 664 666 777 600 640 660 604 444 400 755)
bin_modes=(755 775 777 700 750 640 555 744 770 500)

files=(
  "app/conf/app.yml:$(pick "${cfg_modes[@]}")"
  "app/conf/database.yml:$(pick 600 644 666)"
  "app/conf/.env:$(pick 600 400 664 777)"
  "app/conf/secrets.key:$(pick 600 400 440)"
  "app/conf/tls.crt:$(pick 644 664 444)"
  "app/data/users.db:$(pick "${cfg_modes[@]}")"
  "app/data/cache.db:$(pick 666 664 660 644)"
  "app/data/exports/report 2026.csv:$(pick "${cfg_modes[@]}")"
  "app/data/exports/summary.txt:$(pick "${cfg_modes[@]}")"
  "app/README:$(pick 644 664 444)"
  "app/run.log:$(pick 666 664 640 600)"
  "app/bin/start.sh:$(pick "${bin_modes[@]}")"
  "app/bin/stop.sh:$(pick "${bin_modes[@]}")"
  "app/bin/backup.sh:$(pick "${bin_modes[@]}")"
  "app/bin/healthcheck:$(pick "${bin_modes[@]}")"
  "app/bin/rotate-keys.sh:$(pick 700 777 755 500)"
)
# Guarantee at least one already-strict secret and one wide-open script.
files+=("app/conf/vault.token:400" "app/bin/deploy.sh:777")
: > .lm-state/expected; : > .lm-state/sums
for e in "${files[@]}"; do
  f=${e%%:*}; m=${e##*:}
  printf 'fake content of %s\nline 2\n' "$f" > "$f"
  chmod "$m" "$f"
  case "$f" in app/bin/*) mask=750 ;; *) mask=640 ;; esac
  printf '%s\t%03o\t%s\n' "$f" $((8#$m & 8#$mask)) "$m" >> .lm-state/expected
  cksum < "$f" | sed "s|^|$f\t|" >> .lm-state/sums
done
chmod 775 app/bin app/conf app/data/exports
chmod 750 app/data
mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
find app -type d | LC_ALL=C sort | while IFS= read -r d; do printf '%s\t%s\n' "$d" "$(mode "$d")"; done > .lm-state/dirs
