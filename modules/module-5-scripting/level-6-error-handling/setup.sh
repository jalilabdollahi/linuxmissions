#!/bin/bash
SANDBOX="$1"

echo "payload" > "$SANDBOX/source.txt"

cat > "$SANDBOX/safe_copy.sh" <<'SCRIPT'
#!/bin/bash
cp "$1" copied.txt
echo "copy complete"
SCRIPT

chmod +x "$SANDBOX/safe_copy.sh"
