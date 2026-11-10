#!/bin/bash
# Workon: workon.sh should be sourced to cd into a project and export its
# settings. It finds the projects through $0 (which is "bash" when sourced, so
# it only works from the sandbox itself) and uses `exit` on errors (which closes
# the caller's shell when sourced). Run as ./workon.sh it can't change anything.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

hex() { printf '%04x' $RANDOM; }
for p in api web billing; do
  mkdir -p "projects/$p/src"
  {
    echo "# settings for $p, loaded by workon.sh"
    echo "PROJECT_PORT=$(( 8000 + RANDOM % 1000 ))"
    echo "PROJECT_DB=${p}_dev_$(hex)"
    echo "PROJECT_LOG=/var/log/$p/dev.log"
  } > "projects/$p/.project.env"
  echo "# $p" > "projects/$p/README.md"
done

cat > workon.sh <<'EOF'
#!/bin/bash
# workon.sh - switch to a project: cd into it and export its settings.
# Usage: source workon.sh NAME        (projects live in projects/ next to this file)

here="$(dirname "$0")"
proj="$here/projects/$1"
if [ -z "$1" ] || [ ! -d "$proj" ]; then
  echo "workon: no such project: '$1'" >&2
  exit 1
fi
cd "$proj" || exit 1
set -a
. ./.project.env
set +a
export PROJECT="$1"
echo "now working on $PROJECT (port $PROJECT_PORT)"
EOF
chmod +x workon.sh

cat > COMPLAINTS.txt <<'EOF'
#dev-tools, this week:
 - "./workon.sh api does nothing. It prints 'now working on api' and I'm
    still in the same directory, PROJECT is empty."
 - "source workon.sh api works in the repo root, but from anywhere else it
    says 'no such project'."
 - "I typed `source workon.sh apo` (typo) and my whole terminal closed."
EOF
