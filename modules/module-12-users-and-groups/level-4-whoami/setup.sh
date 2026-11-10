#!/bin/bash
# Fake It: deploy.sh only runs for the account named in deploy.allowed, but it
# compares that name with $USER, which any caller can set. The player makes the
# guard use the effective identity (whoami / id -un). Version is random.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p build

ver="2026.11.$((RANDOM % 9 + 1))-$(printf '%04x%03x' $RANDOM $((RANDOM % 4096)))"
echo "$ver" > build/VERSION
mkdir -p .pkg/app && printf 'release %s\n' "$ver" > .pkg/app/RELEASE
tar -czf "build/app-$ver.tar.gz" -C .pkg app && rm -rf .pkg

echo release > deploy.allowed

cat > deploy.sh <<'SCRIPT'
#!/bin/bash
# deploy.sh - copy the current build to the staging web root.
# Only the account named in deploy.allowed may deploy.
here=$(cd "$(dirname "$0")" && pwd)
allowed=$(cat "$here/deploy.allowed")

if [ "$USER" != "$allowed" ]; then
  echo "deploy.sh: refusing to run as $USER (only $allowed may deploy)" >&2
  exit 1
fi

build=$(cat "$here/build/VERSION")
mkdir -p "$here/staging"
cp "$here"/build/*.tar.gz "$here/staging/"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) deployed $build as $allowed" >> "$here/deploy.log"
echo "deploy.sh: build $build is on staging"
SCRIPT
chmod 755 deploy.sh

cat > NOTE.txt <<'EOF2'
From the security review (SEC-412):

  USER=release ./deploy.sh

works for anyone on the box. $USER and $LOGNAME are just environment variables
that the caller controls. The guard must look at who the process really runs as.
EOF2
