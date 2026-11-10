#!/bin/bash
# Reference solution: rewrite rename.sh with a heredoc, then use it on incoming/.
cat > rename.sh <<'EOF'
#!/bin/bash
# rename.sh DIR - mark the reports in DIR as processed: NAME.txt -> NAME.bak
for f in "$1"/*.txt; do
  [ -e "$f" ] || continue
  mv -- "$f" "${f%.txt}.bak"
done
EOF
bash rename.sh incoming
