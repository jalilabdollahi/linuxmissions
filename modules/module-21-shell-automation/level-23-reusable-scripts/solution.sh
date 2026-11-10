#!/bin/bash
# Reference solution: settings from defaults, then the config file, then the
# environment, then a while/case option loop; names on stdout, messages on
# stderr, exit 0/1/2.
cat > prune.sh <<'SCRIPT'
#!/bin/bash
# prune.sh [OPTIONS] [DIR] - delete old *.tar.gz backups, keep the newest N
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: prune.sh [OPTIONS] [DIR]
Delete the *.tar.gz files directly in DIR (default: backups) except the N
most recently modified ones.

  -k, --keep N     keep the N newest backups (default 7)
  -n, --dry-run    only print what would be deleted
  -h, --help       show this help
  --               end of options

Settings: defaults < config file ($PRUNE_CONFIG or ~/.config/prune.conf,
keep=N and dir=PATH lines) < PRUNE_KEEP / PRUNE_DIR < command line.
stdout: deleted file names, oldest first. stderr: messages.
Exit status: 0 done, 1 DIR does not exist, 2 usage error.
EOF
}
log() { echo "prune: $*" >&2; }
usage_error() {
  echo "prune: $*" >&2
  echo "Try 'prune.sh --help'." >&2
  exit 2
}

# 1. defaults, 2. config file, 3. environment
keep=7
dir=backups
config="${PRUNE_CONFIG:-$HOME/.config/prune.conf}"
if [ -f "$config" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      keep) keep=$value ;;
      dir)  dir=$value ;;
    esac
  done < "$config"
fi
keep="${PRUNE_KEEP:-$keep}"
dir="${PRUNE_DIR:-$dir}"

# 4. command line
dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    -n|--dry-run) dry_run=1 ;;
    -k|--keep)    [ $# -ge 2 ] || usage_error "$1 needs a number"
                  keep=$2; shift ;;
    --keep=*)     keep=${1#--keep=} ;;
    --)           shift; break ;;
    -?*)          usage_error "unknown option: $1" ;;
    *)            break ;;
  esac
  shift
done
[ $# -le 1 ] || usage_error "only one DIR, got $#"
[ $# -eq 1 ] && dir=$1
case "$keep" in
  ''|*[!0-9]*) usage_error "keep must be a number, got '$keep'" ;;
esac
[ -d "$dir" ] || { log "no such directory: $dir"; exit 1; }

shopt -s nullglob
files=("$dir"/*.tar.gz)
count=${#files[@]}
excess=$(( count - keep ))
if [ "$excess" -le 0 ]; then
  log "$count backup(s) in $dir, keeping $keep: nothing to do"
  exit 0
fi
log "$count backup(s) in $dir, keeping $keep, removing $excess$( [ "$dry_run" = 1 ] && echo ' (dry run)')"
ls -1dtr -- "${files[@]}" | sed -n "1,${excess}p" | while IFS= read -r path; do
  if [ "$dry_run" = 0 ]; then
    rm -f -- "$path"
  fi
  printf '%s\n' "${path##*/}"
done
SCRIPT
./prune.sh --help
./prune.sh -n -k 5
./prune.sh -k 5
./prune.sh -k 5
