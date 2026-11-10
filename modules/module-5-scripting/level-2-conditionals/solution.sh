#!/bin/bash
# Reference solution: rewrite check_file.sh with a heredoc.
cat > check_file.sh <<'EOF'
#!/bin/bash
# check_file.sh PATH - say what PATH is before the backup job touches it
if [ -f "$1" ]; then
  echo "FILE"
elif [ -d "$1" ]; then
  echo "DIR"
else
  echo "MISSING"
  exit 1
fi
EOF
