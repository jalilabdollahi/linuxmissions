#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/cleanup.sh" <<'SCRIPT'
#!/bin/bash
echo "cleanup"
SCRIPT

chmod +x "$SANDBOX/cleanup.sh"
touch "$SANDBOX/crontab.txt"
