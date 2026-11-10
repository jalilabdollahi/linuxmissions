#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/incoming/archive"
echo "alpha"            > "$SANDBOX/incoming/sales.txt"
echo "beta"             > "$SANDBOX/incoming/q3 report.txt"
echo "gamma"            > "$SANDBOX/incoming/inventory.txt"
echo "keep me"          > "$SANDBOX/incoming/notes.md"
echo "old export"       > "$SANDBOX/incoming/export.txt.old"
echo "already archived" > "$SANDBOX/incoming/archive/2025.txt"

cat > "$SANDBOX/rename.sh" <<'SCRIPT'
#!/bin/bash
# rename.sh DIR - mark the reports in DIR as processed: NAME.txt -> NAME.bak
# TODO
SCRIPT

chmod +x "$SANDBOX/rename.sh"
