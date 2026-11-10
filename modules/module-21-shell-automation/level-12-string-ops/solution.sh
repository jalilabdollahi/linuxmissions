#!/bin/bash
# Strip the directory with ${1##*/}, then let one anchored regex check the
# whole format and capture the five parts in BASH_REMATCH.
cat > parse_artifact.sh <<'SCRIPT'
#!/bin/bash
# parse_artifact.sh FILE - NAME-VERSION-OS-ARCH.EXT, bash built-ins only
file=${1##*/}
re='^([a-z0-9][a-z0-9-]*)-([0-9]+\.[0-9]+\.[0-9]+)-([a-z0-9]+)-([a-z0-9]+)\.(tar\.gz|tar\.xz|zip)$'
if [[ $file =~ $re ]]; then
  echo "name=${BASH_REMATCH[1]} version=${BASH_REMATCH[2]} os=${BASH_REMATCH[3]} arch=${BASH_REMATCH[4]} ext=${BASH_REMATCH[5]}"
else
  echo "parse_artifact: not an artifact name: $1" >&2
  exit 1
fi
SCRIPT
for f in dist/*; do
  env -i PATH=/nonexistent /bin/bash ./parse_artifact.sh "$f"
done
