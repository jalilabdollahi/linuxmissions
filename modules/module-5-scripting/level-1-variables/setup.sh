#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/greet.sh" <<'SCRIPT'
#!/bin/bash
# TODO: print a greeting using the first argument
SCRIPT

chmod +x "$SANDBOX/greet.sh"
