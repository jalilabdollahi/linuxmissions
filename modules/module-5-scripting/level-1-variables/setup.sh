#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/greet.sh" <<'SCRIPT'
#!/bin/bash
# greet.sh NAME - say hello to the new team member
# TODO: greet the person named in the first argument ("stranger" if none)
SCRIPT

chmod +x "$SANDBOX/greet.sh"
