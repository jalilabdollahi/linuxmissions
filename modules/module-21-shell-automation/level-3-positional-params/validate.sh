#!/bin/bash
# Runs archive.sh in a scratch dir (full of files, so an unquoted * expands)
# with a validator-owned upload mock that writes its argv NUL-separated, and
# compares that argv with the arguments archive.sh was given. Also checks the
# usage error (stderr, exit 2, no upload) and the "archiving N file(s)" line.
SANDBOX="$1"
SCRIPT="$SANDBOX/archive.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ archive.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/tools"
cp "$SCRIPT" "$WORK/archive.sh"
cat > "$WORK/tools/upload" <<'EOF'
#!/bin/bash
printf '%s\0' "$@" >> "$ARGV_LOG"
printf '\n' >> "$ARGV_LOG.calls"
EOF
chmod +x "$WORK/tools/upload"
touch "$WORK/aaa.pdf" "$WORK/zzz.csv"
cd "$WORK" || exit 1
export ARGV_LOG="$WORK/argv.bin"
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

show() {  # print NUL-separated args as <a> <b> ...
  tr '\0' '\n' < "$1" | sed 's/.*/<&>/' | tr '\n' ' ' | cut -c1-160
}

# run LABEL ARG... : archive.sh must call upload once with --bucket BUCKET FILE...
run() {
  label=$1; shift
  rm -f argv.bin argv.bin.calls want.bin
  $LIMIT bash ./archive.sh "$@" </dev/null >out 2>err
  code=$?
  printf '%s\0' --bucket "$@" > want.bin
  if [ "$code" != 0 ]; then
    echo "❌ $label: archive.sh exited with $code ($(head -n 1 err))"
    exit 1
  fi
  calls=$(wc -l < argv.bin.calls 2>/dev/null | tr -d ' ')
  if [ "${calls:-0}" != 1 ]; then
    echo "❌ $label: upload was called ${calls:-0} times, expected once"
    exit 1
  fi
  if ! cmp -s argv.bin want.bin; then
    echo "❌ $label: upload received $(show argv.bin)  but expected $(show want.bin)"
    exit 1
  fi
  n=$(( $# - 1 ))
  if [ "$(head -n 1 out)" != "archiving $n file(s) to $1" ]; then
    echo "❌ $label: first line was '$(head -n 1 out)', expected 'archiving $n file(s) to $1'"
    exit 1
  fi
}

run "plain names" finance a.pdf b.csv
run "names with spaces" "finance archive" "reports/2026 Q3/summary final.pdf" "board  notes.txt"
run "a file literally called *" scratch '*' 'c.txt'
run "an empty argument" scratch 'x.pdf' '' 'y.pdf'
run "a name with tabs and a trailing space" scratch $'tab\tname.txt' 'trail.txt ' "it's.pdf"

for args in "" "onlybucket"; do
  rm -f argv.bin argv.bin.calls
  # shellcheck disable=SC2086
  $LIMIT bash ./archive.sh $args </dev/null >out 2>err
  code=$?
  what="./archive.sh${args:+ $args}"
  if [ "$code" != 2 ]; then
    echo "❌ $what (fewer than 2 arguments) exited with $code, expected 2"
    exit 1
  fi
  if [ -e argv.bin.calls ]; then
    echo "❌ $what (fewer than 2 arguments) still called upload"
    exit 1
  fi
  if [ ! -s err ] || [ -s out ]; then
    echo "❌ $what: the usage message must go to stderr (and nothing to stdout)"
    exit 1
  fi
done

echo "✅ archive.sh hands every argument to upload exactly as it received it, and rejects bad calls"
exit 0
