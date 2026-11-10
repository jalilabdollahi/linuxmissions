#!/bin/bash
# Behind the Symlink: deploy/current -> releases/live -> <random release>.
# The live release is picked at random and is not the newest one.
SANDBOX="$1"
mkdir -p "$SANDBOX/deploy/releases"
cd "$SANDBOX/deploy/releases" || exit 1

names=()
for day in 03 04 05 06 07 08; do
  name="2026-11-${day}_$(printf '%02d%02d' $(( 8 + RANDOM % 12 )) $(( RANDOM % 60 )))"
  mkdir "$name"
  printf 'release %s\nbuilt by ci-runner-%d\n' "$name" $(( RANDOM % 9 + 1 )) > "$name/VERSION"
  mkdir "$name/bin" "$name/static"
  names+=("$name")
done
# live: one of the four middle releases; previous: the one before it
i=$(( 1 + RANDOM % 4 ))
ln -s "${names[$i]}" live
cd .. || exit 1
ln -s releases/live current
ln -s "releases/${names[$(( i - 1 ))]}" previous

cat > RUNBOOK.txt <<'EOF'
ROLLBACK RUNBOOK (app servers)
1. cd into deploy/current and record where you are:
     - the path as you reached it          -> logical.txt
     - the real release directory behind it -> physical.txt
   Do this BEFORE touching any symlink. `current` is a link to `live`,
   which is itself a link, and both get replaced during a rollback.
2. Point releases/live at the previous release.
3. Restart the app and check /healthz.
EOF
