#!/bin/bash
SANDBOX="$1"

mkdir -p "$SANDBOX/incoming"
echo "alpha" > "$SANDBOX/incoming/a.txt"
echo "beta" > "$SANDBOX/incoming/b.txt"
echo "gamma" > "$SANDBOX/incoming/c.txt"
echo "keep me" > "$SANDBOX/incoming/notes.md"

cat > "$SANDBOX/rename.sh" <<'SCRIPT'
#!/bin/bash
# TODO: rename all .txt files in the directory passed as $1 to .bak
SCRIPT

chmod +x "$SANDBOX/rename.sh"
