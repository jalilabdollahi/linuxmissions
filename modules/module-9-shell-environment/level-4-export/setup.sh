#!/bin/bash
# Set But Not Seen: launcher.sh reads APP_MODE/APP_REGION from its environment.
# A plain assignment in the shell never reaches it. Every run is signed with a
# per-setup id, so run.log can't be typed by hand.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

regions=(eu-north-1 eu-west-3 us-east-2 ap-south-1 ca-central-1 sa-east-1)
region="${regions[$(( RANDOM % 6 ))]}"
printf '%04x%04x%04x\n' $RANDOM $RANDOM $RANDOM > .launcher-id

cat > launcher.sh <<'EOF'
#!/bin/bash
# launcher.sh - starts the billing worker.
# Settings come ONLY from the environment:
#   APP_MODE    dev | prod    (default: dev)
#   APP_REGION  region code   (default: local)
# Every start is recorded in run.log (overwritten each time).
here="$(cd "$(dirname "$0")" && pwd)"
mode="${APP_MODE:-dev}"
region="${APP_REGION:-local}"

[ -n "${APP_MODE+set}" ]   || echo "launcher: APP_MODE is not in my environment, using dev" >&2
[ -n "${APP_REGION+set}" ] || echo "launcher: APP_REGION is not in my environment, using local" >&2

id="$(cat "$here/.launcher-id" 2>/dev/null)"
sig="$(printf '%s|%s|%s' "$id" "$mode" "$region" | cksum | cut -d' ' -f1)"
echo "started mode=$mode region=$region sig=$sig" > "$here/run.log"
echo "worker started in $mode mode, region $region"
EOF
chmod +x launcher.sh

cat > TICKET.txt <<EOF
CHG-2207  Move the billing worker to production
------------------------------------------------
Start the worker with ./launcher.sh in production mode for the new region.

  APP_MODE:   prod
  APP_REGION: $region

run.log must show the production start before we close this change.
EOF

cat > shell-notes.txt <<EOF
What Kim typed yesterday (the worker still came up in dev mode):

  \$ APP_MODE=prod
  \$ APP_REGION=$region
  \$ echo \$APP_MODE
  prod
  \$ ./launcher.sh
  launcher: APP_MODE is not in my environment, using dev
  launcher: APP_REGION is not in my environment, using local
  worker started in dev mode, region local
EOF

echo "started mode=dev region=local sig=$(printf '%s|%s|%s' "$(cat .launcher-id)" dev local | cksum | cut -d' ' -f1)" > run.log
