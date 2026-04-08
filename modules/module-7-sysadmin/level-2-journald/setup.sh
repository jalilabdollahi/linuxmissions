#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/journal-recent.log" <<'EOF'
Apr 08 13:10:00 app[101]: info startup complete
Apr 08 13:18:00 app[101]: error failed to load config
Apr 08 13:33:00 app[101]: warning retry scheduled
Apr 08 13:44:00 app[101]: error database timeout
EOF

cat > "$SANDBOX/journal-all.log" <<'EOF'
Apr 08 11:55:00 app[101]: error old failure
Apr 08 13:10:00 app[101]: info startup complete
Apr 08 13:18:00 app[101]: error failed to load config
Apr 08 13:33:00 app[101]: warning retry scheduled
Apr 08 13:44:00 app[101]: error database timeout
EOF

cat > "$SANDBOX/journalctl" <<'SCRIPT'
#!/bin/bash
if printf '%s\n' "$*" | grep -q -- '--since'; then
  cat journal-recent.log
else
  cat journal-all.log
fi
SCRIPT

chmod +x "$SANDBOX/journalctl"
