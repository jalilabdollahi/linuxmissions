#!/bin/bash
# Rewrite the draft: drop .5, shift 4->5 ... 1->2 (oldest first, skipping gaps), new .1.
cat > rotate.sh <<'EOF'
#!/bin/bash
# rotate.sh - keep 5 generations of the site backup
set -eu
cd "$(dirname "$0")"
mkdir -p backups
rm -f backups/site.tar.gz.5
for n in 4 3 2 1; do
  if [ -e "backups/site.tar.gz.$n" ]; then
    mv "backups/site.tar.gz.$n" "backups/site.tar.gz.$((n + 1))"
  fi
done
tar -czf backups/site.tar.gz.1 site
EOF
chmod +x rotate.sh
./rotate.sh
ls backups
