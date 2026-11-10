#!/bin/bash
# Locate projects/ through BASH_SOURCE, return instead of exit, refuse to run unsourced.
cat > workon.sh <<'EOF'
#!/bin/bash
# workon.sh - switch to a project: cd into it and export its settings.
# Usage: source workon.sh NAME        (projects live in projects/ next to this file)

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "workon.sh changes your current shell, so it must be sourced: source $0 NAME" >&2
  exit 1
fi
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
proj="$here/projects/$1"
if [ -z "$1" ] || [ ! -d "$proj" ]; then
  echo "workon: no such project: '$1'" >&2
  return 1
fi
cd "$proj" || return 1
set -a
. ./.project.env
set +a
export PROJECT="$1"
echo "now working on $PROJECT (port $PROJECT_PORT)"
EOF
bash -c "cd / && source '$PWD/workon.sh' api; pwd; source '$PWD/workon.sh' apo; echo alive \$?"
