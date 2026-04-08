#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/passwd.mock" <<'EOF'
root:x:0:0:root:/root:/bin/bash
EOF

cat > "$SANDBOX/group.mock" <<'EOF'
root:x:0:
docker:x:999:
EOF

cat > "$SANDBOX/useradd" <<'SCRIPT'
#!/bin/bash
user="$1"
echo "$user:x:1001:1001:$user:/home/$user:/bin/bash" >> passwd.mock
SCRIPT

cat > "$SANDBOX/usermod" <<'SCRIPT'
#!/bin/bash
if [ "$1" = "-aG" ]; then
  group="$2"
  user="$3"
  awk -F: -v grp="$group" -v usr="$user" 'BEGIN{OFS=":"} $1==grp {$4=($4 ? $4 "," usr : usr)} {print}' group.mock > group.mock.tmp
  mv group.mock.tmp group.mock
fi
SCRIPT

cat > "$SANDBOX/id" <<'SCRIPT'
#!/bin/bash
user="$1"
grep "^$user:" passwd.mock >/dev/null && grep '^docker:' group.mock
SCRIPT

chmod +x "$SANDBOX/useradd" "$SANDBOX/usermod" "$SANDBOX/id"
