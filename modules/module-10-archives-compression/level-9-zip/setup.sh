#!/bin/bash
# Refresh the Hand-over: last week's handover.zip (with an archive comment) and
# this week's handover/ folder. The zip must be synced in place.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
H=handover
mkdir -p "$H/docs" "$H/config" "$H/scripts" "$H/data"

rand_rows() {  # rand_rows N SEED: CSV rows that cannot be guessed
  awk -v n="$1" -v seed="$2" 'BEGIN { srand(seed); print "id,device,firmware,status"
    for (i = 1; i <= n; i++) printf "%d,GW-%05d,4.%d.%d,%s\n", i, int(rand()*99999), int(rand()*9), int(rand()*20), (rand() < 0.8 ? "ok" : "rma") }'
}

# --- last week's state ---
printf '# ACME gateway hand-over\n\nSee docs/install.md, then docs/latest for what changed.\n' > "$H/README.md"
printf '# Install\n\n1. Flash the image.\n2. Copy config/settings.example.yml to /etc/acme/settings.yml.\n3. Run the migration script in scripts/.\n' > "$H/docs/install.md"
printf '# Release notes v3\n\n- Modbus polling every 5 s\n- Fixed NTP drift\n' > "$H/docs/release-notes-v3.md"
ln -s release-notes-v3.md "$H/docs/latest"
printf 'site: acme-plant-2\npoll_interval: 5\nupstream: mqtts://broker.acme.example:8883\n' > "$H/config/settings.example.yml"
printf '[legacy]\nserial=/dev/ttyS0\nbaud=9600\n' > "$H/config/legacy.ini"
printf '#!/bin/sh\necho "migrating v2 -> v3"\n' > "$H/scripts/migrate-v3.sh"
rand_rows 40 "$RANDOM" > "$H/data/devices.csv"
chmod +x "$H/scripts/migrate-v3.sh"
find "$H" -exec touch -h -t 202611030900 {} +

comment="ACME hand-over, do not remove. Portal ref HO-$(( RANDOM % 9000 + 1000 ))-$(( RANDOM % 90 + 10 ))"
zip -q -r -y "$H.zip" "$H"
printf '%s\n' "$comment" | zip -q -z "$H.zip"
printf '%s' "$comment" > .lm-state/comment
cksum < "$H.zip" > .lm-state/lastweek.sum

# --- this week's changes ---
printf 'site: acme-plant-2\npoll_interval: 2\nupstream: mqtts://broker.acme.example:8883\ntls_ca: /etc/acme/ca.pem\nbatch_size: %d\n' $(( RANDOM % 400 + 100 )) > "$H/config/settings.example.yml"
rand_rows 55 "$RANDOM" > "$H/data/devices.csv"
rm "$H/config/legacy.ini" "$H/scripts/migrate-v3.sh"
printf '# Release notes v4\n\n- Polling every 2 s\n- TLS to the broker\n- Removed the serial (legacy.ini) driver\n' > "$H/docs/release-notes-v4.md"
printf '#!/bin/sh\necho "migrating v3 -> v4"\n' > "$H/scripts/migrate-v4.sh"
chmod +x "$H/scripts/migrate-v4.sh"
ln -sfn release-notes-v4.md "$H/docs/latest"
for f in config/settings.example.yml data/devices.csv docs/release-notes-v4.md scripts/migrate-v4.sh docs/latest; do
  touch -h -t 202611090930 "$H/$f"
done

# What handover/ must still look like at the end.
(cd "$H" && find . \( -type f -o -type l \) | LC_ALL=C sort | while read -r p; do
  if [ -L "$p" ]; then echo "L $p $(readlink "$p")"; else echo "F $p $(cksum < "$p" | tr ' ' :)"; fi
done) > .lm-state/tree
