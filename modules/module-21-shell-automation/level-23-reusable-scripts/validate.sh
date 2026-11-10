#!/bin/bash
# Runs prune.sh about 20 times against generated backup folders whose names
# have spaces and whose mtimes do not follow the names: help, usage errors
# (exit 2), a missing DIR (exit 1), dry runs, a real run, a second run, the
# settings precedence (defaults < config < env < command line), the default
# config in ~/.config, and a DIR that starts with a dash after --.
# stdout must hold only the file names, oldest first.
SANDBOX="$1"
SCRIPT="$SANDBOX/prune.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ prune.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"
cp "$SCRIPT" "$WORK/prune.sh"
mkdir -p "$WORK/home" "$WORK/elsewhere"

# Nine backups, oldest first; their names sort differently.
ORDER=("zz final 2026-09-01.tar.gz" "app 2026-09-02.tar.gz" "app 2026-09-03.tar.gz"
       "manual  two spaces.tar.gz" "app 2026-09-04.tar.gz" "app 2026-09-05.tar.gz"
       "Aardvark export.tar.gz" "app 2026-09-06.tar.gz" "app 2026-09-07.tar.gz")
# fill DIR: the nine backups, plus files that must never be touched
fill() {
  rm -rf "$1"; mkdir -p "$1/old"
  local i=0
  while [ $i -lt ${#ORDER[@]} ]; do
    echo "$i" > "$1/${ORDER[$i]}"
    touch -t "$(printf '202609%02d0300' $((i + 1)))" "$1/${ORDER[$i]}"
    i=$((i + 1))
  done
  echo note > "$1/notes.txt"
  echo sum > "$1/app 2026-09-07.tar.gz.sha256"
  echo ancient > "$1/old/ancient.tar.gz"; touch -t 202001010000 "$1/old/ancient.tar.gz"
}
# oldest N: the names that keep=9-N should delete, oldest first
oldest() { local i=0; while [ $i -lt "$1" ]; do printf '%s\n' "${ORDER[$i]}"; i=$((i + 1)); done; }
listing() { (cd "$1" && find . | LC_ALL=C sort); }

# run DIR_TO_RUN_IN [VAR=value...] -- ARGS...
run() {
  local where="$1"; shift
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  (cd "$where" && $LIMIT env -u PRUNE_KEEP -u PRUNE_DIR -u PRUNE_CONFIG HOME="$WORK/home" \
     ${envs[@]+"${envs[@]}"} bash "$WORK/prune.sh" "$@" </dev/null >"$WORK/out" 2>"$WORK/err")
  CODE=$?
}
say() { printf '%s' "$*"; }
# expect_list WHAT N: stdout must be exactly the N oldest names
expect_list() {
  if [ "$CODE" != 0 ]; then
    echo "❌ $1: exit status $CODE, expected 0 ($(head -1 "$WORK/err"))"
    exit 1
  fi
  if [ "$(cat "$WORK/out")" != "$(oldest "$2")" ]; then
    got="$(grep -c . "$WORK/out")"
    if [ "$got" = "$2" ]; then
      echo "❌ $1: stdout should list the $2 oldest backups by modification time, oldest first, names only; got: $(head -2 "$WORK/out" | tr '\n' '|')"
    else
      echo "❌ $1: expected exactly $2 file name(s) on stdout (and nothing else), got $got line(s): $(head -2 "$WORK/out" | tr '\n' '|')"
    fi
    exit 1
  fi
}
# expect_error WHAT CODE
expect_error() {
  if [ "$CODE" != "$2" ]; then
    echo "❌ $1: exit status $CODE, expected $2"
    exit 1
  fi
  if [ -s "$WORK/out" ]; then
    echo "❌ $1: the error went to stdout; messages belong on stderr"
    exit 1
  fi
  if [ ! -s "$WORK/err" ]; then
    echo "❌ $1: exits $2 but prints no message on stderr"
    exit 1
  fi
}

B="$WORK/nightly backups"
fill "$B"
before="$(listing "$B")"

# --- help ---
for h in --help -h; do
  run "$WORK" -- "$h"
  if [ "$CODE" != 0 ] || ! grep -q -- '--dry-run' "$WORK/out" || ! grep -q -- '--keep' "$WORK/out"; then
    echo "❌ prune.sh $h should print a usage text (mentioning --keep and --dry-run) on stdout and exit 0"
    exit 1
  fi
done

# --- usage errors and a missing DIR; nothing may be deleted ---
run "$WORK" -- --bogus "$B";          expect_error "prune.sh --bogus" 2
run "$WORK" -- -k;                    expect_error "prune.sh -k (no number)" 2
run "$WORK" -- --keep=abc "$B";       expect_error "prune.sh --keep=abc" 2
run "$WORK" -- -k 3 "$B" "$WORK/elsewhere"; expect_error "prune.sh with two DIRs" 2
run "$WORK" -- -k 3 "$WORK/missing";  expect_error "prune.sh -k 3 on a DIR that does not exist" 1
if [ "$(listing "$B")" != "$before" ]; then
  echo "❌ a call that ended in a usage error still deleted files"
  exit 1
fi

# --- dry runs ---
run "$WORK" -- -n -k 3 "$B";               expect_list "prune.sh -n -k 3 DIR" 6
run "$WORK" -- --dry-run --keep=4 "$B";    expect_list "prune.sh --dry-run --keep=4 DIR" 5
run "$WORK" -- --dry-run --keep 9 "$B";    expect_list "prune.sh --dry-run --keep 9 DIR" 0
if [ "$(listing "$B")" != "$before" ]; then
  echo "❌ --dry-run deleted files"
  exit 1
fi

# --- settings precedence (dry runs): defaults < config < env < command line ---
mkdir -p "$WORK/elsewhere/backups"
fill "$WORK/elsewhere/backups"
run "$WORK/elsewhere" -- -n;              expect_list "prune.sh -n with no settings at all (keep 7, DIR backups)" 2
mkdir -p "$WORK/home/.config"
printf '# my prune settings\nkeep=5\n' > "$WORK/home/.config/prune.conf"
run "$WORK/elsewhere" -- -n;              expect_list "prune.sh -n with keep=5 in ~/.config/prune.conf" 4
printf '# team settings\n\nkeep=4\ndir=%s\n' "$B" > "$WORK/team.conf"
run "$WORK/elsewhere" PRUNE_CONFIG="$WORK/team.conf" -- -n
expect_list "prune.sh -n with PRUNE_CONFIG (keep=4, dir=...)" 5
run "$WORK/elsewhere" PRUNE_CONFIG="$WORK/team.conf" PRUNE_KEEP=2 -- -n
expect_list "prune.sh -n with keep=4 in the config and PRUNE_KEEP=2 (env beats config)" 7
run "$WORK/elsewhere" PRUNE_CONFIG="$WORK/team.conf" PRUNE_KEEP=2 -- -n -k 6
expect_list "prune.sh -n -k 6 with PRUNE_KEEP=2 (the flag beats env)" 3
run "$WORK/elsewhere" PRUNE_CONFIG="$WORK/team.conf" PRUNE_DIR="$WORK/elsewhere/backups" PRUNE_KEEP=8 -- -n
expect_list "prune.sh -n with dir= in the config and PRUNE_DIR (env beats config)" 1
run "$WORK" PRUNE_DIR="$WORK/missing" PRUNE_KEEP=8 -- -n "$B"
expect_list "prune.sh -n DIR with PRUNE_DIR set elsewhere (the argument beats env)" 1
rm -f "$WORK/home/.config/prune.conf"
if [ "$(listing "$B")" != "$before" ]; then
  echo "❌ a --dry-run deleted files"
  exit 1
fi

# --- a DIR that starts with a dash ---
fill "$WORK/-odd dir"
run "$WORK" -- -n -k 7 -- "-odd dir";   expect_list "prune.sh -n -k 7 -- \"-odd dir\"" 2

# --- the real thing, twice ---
run "$WORK" -- -k 3 "$B";               expect_list "prune.sh -k 3 DIR" 6
want="$(cd "$B" && for f in "${ORDER[@]:6}"; do echo "./$f"; done; echo ./notes.txt; echo "./app 2026-09-07.tar.gz.sha256"; echo ./old; echo ./old/ancient.tar.gz; echo .)"
if [ "$(listing "$B")" != "$(printf '%s\n' "$want" | LC_ALL=C sort)" ]; then
  echo "❌ after prune.sh -k 3 DIR, the folder should hold the 3 newest backups and every other file untouched"
  exit 1
fi
run "$WORK" -- -k 3 "$B"
if [ "$CODE" != 0 ] || [ -s "$WORK/out" ]; then
  echo "❌ running prune.sh -k 3 DIR a second time should delete nothing, print nothing on stdout and exit 0 (status $CODE)"
  exit 1
fi

echo "✅ prune.sh is a proper tool: options, help, precedence, dry run, clean stdout and exit codes"
exit 0
