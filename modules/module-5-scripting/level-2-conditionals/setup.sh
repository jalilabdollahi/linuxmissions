#!/bin/bash
SANDBOX="$1"

echo "present" > "$SANDBOX/present.txt"

cat > "$SANDBOX/check_file.sh" <<'SCRIPT'
#!/bin/bash
# TODO: print EXISTS or MISSING based on the first argument
SCRIPT

chmod +x "$SANDBOX/check_file.sh"
