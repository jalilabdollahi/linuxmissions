#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/process.sh" <<SCRIPT
#!/bin/bash
sleep 15
echo "done" > "$SANDBOX/result.txt"
SCRIPT

chmod +x "$SANDBOX/process.sh"
