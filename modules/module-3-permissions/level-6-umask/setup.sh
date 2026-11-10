#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/start_app.sh" <<'SCRIPT'
#!/bin/bash
# Report app: writes its log and the daily reports under data/.
# Policy: owner full access, group read-only, others nothing.
umask 000
cd "$(dirname "$0")" || exit 1
mkdir -p data/reports/daily
echo "$(date '+%F %T') app started" >> data/app.log
echo "region,total"  > data/reports/daily/sales.csv
echo "north,1200"   >> data/reports/daily/sales.csv
echo "ok"            > data/reports/status.txt
echo "start_app.sh: reports written"
SCRIPT
chmod 755 "$SANDBOX/start_app.sh"
# The app has already run once with the bad umask
bash "$SANDBOX/start_app.sh" >/dev/null 2>&1
