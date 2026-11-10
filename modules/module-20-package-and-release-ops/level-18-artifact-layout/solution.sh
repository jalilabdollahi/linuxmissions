#!/bin/bash
cat > build.sh <<'SCRIPT'
#!/bin/bash
set -e
cd "$(dirname "$0")"
rm -rf stage dist
mkdir -p stage dist
cp -R src/agent stage/agent-1.4.2
find stage -type d -exec chmod 755 {} +
find stage -type f -exec chmod 644 {} +
chmod 755 stage/agent-1.4.2/bin/*
find stage/agent-1.4.2/conf -type f -exec chmod 640 {} +
LC_ALL=C tar -C stage --exclude=.DS_Store --exclude='*.o' --exclude='*~' \
  --sort=name --owner=0 --group=0 --numeric-owner --mtime=@1767225600 \
  -cf - agent-1.4.2 | gzip -n > dist/agent-1.4.2.tar.gz
SCRIPT
bash build.sh
