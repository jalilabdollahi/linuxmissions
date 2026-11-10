#!/bin/bash
# Runs the player's ingest.sh against fixtures it has never seen (generated
# here with random names and sizes) and compares what it reports and writes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "❌ this level needs bash 4 or newer (globstar); play it with ./play.sh --docker"
  exit 1
fi
if [ ! -f ingest.sh ]; then
  echo "❌ ingest.sh is missing (type reset)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

mkcsv() {  # mkcsv FILE ROWS: a CSV with a header line and ROWS data lines
  mkdir -p "$(dirname "$1")"
  { echo "id,value"; for i in $(seq 1 "$2"); do echo "$i,$RANDOM"; done; } > "$1"
}
# run FIXTURE: ingest.sh from the sandbox, pointed at the fixture dir
run() {
  (cd "$WORK" && $LIMIT env -i PATH=/usr/bin:/bin HOME="$WORK" bash "$SANDBOX/ingest.sh" "$WORK/$1" \
     </dev/null >"$WORK/$1.out" 2>"$WORK/$1.err")
  echo $? > "$WORK/$1.code"
}
reported() { grep '^ingested ' "$WORK/$1.out" | sed 's/^ingested //' | LC_ALL=C sort; }

check() {  # check NAME DESCRIPTION EXPECTED-LINES...
  local name="$1" desc="$2"; shift 2
  local want got files=0 rows=0 line n
  want="$(printf '%s\n' "$@" | grep . | LC_ALL=C sort)"
  got="$(reported "$name")"
  if [ "$got" != "$want" ]; then
    if printf '%s\n' "$got" | grep -q '\*'; then
      echo "❌ $desc: ingest.sh processed a literal '*' pattern ($(printf '%s\n' "$got" | grep '\*' | head -1)); an unmatched glob should expand to nothing"
    elif [ -z "$want" ]; then
      echo "❌ $desc: ingest.sh reported files although incoming/ has no CSV: $(printf '%s\n' "$got" | head -1)"
    else
      miss="$(LC_ALL=C comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)"
      extra="$(LC_ALL=C comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$got") | head -1)"
      if [ -n "$miss" ]; then
        echo "❌ $desc: ingest.sh did not ingest $miss"
      else
        echo "❌ $desc: ingest.sh should not have ingested $extra"
      fi
    fi
    exit 1
  fi
  for line in "$@"; do
    [ -z "$line" ] && continue
    n="${line##*(}"; n="${n%% rows)}"
    files=$(( files + 1 )); rows=$(( rows + n ))
  done
  if [ "$(cat "$WORK/$name/summary.txt" 2>/dev/null)" != "files=$files rows=$rows" ]; then
    echo "❌ $desc: summary.txt should say 'files=$files rows=$rows'"
    exit 1
  fi
}

# Fixture 1: an empty upload directory.
mkdir -p "$WORK/empty/incoming"
run empty
check empty "with an empty incoming/"

# Fixture 2: nested directories, a name with a space, a hidden partial upload.
a=$(( 2 + RANDOM % 9 )); b=$(( 2 + RANDOM % 9 )); c=$(( 2 + RANDOM % 9 )); d=$(( 2 + RANDOM % 9 ))
y=$(( 2020 + RANDOM % 6 ))
mkcsv "$WORK/nested/incoming/top-$RANDOM.csv" $a;              f1=$(cd "$WORK/nested" && ls incoming/top-*.csv)
mkcsv "$WORK/nested/incoming/$y/q$(( RANDOM % 4 + 1 ))/shop $RANDOM.csv" $b
f2=$(cd "$WORK/nested" && ls incoming/$y/q*/*.csv)
mkcsv "$WORK/nested/incoming/$y/archive/deep/old-$RANDOM.csv" $c; f3=$(cd "$WORK/nested" && ls incoming/$y/archive/deep/*.csv)
mkcsv "$WORK/nested/incoming/$y/.upload-$RANDOM.csv" $d
echo "not a csv" > "$WORK/nested/incoming/$y/notes.txt"
run nested
check nested "with files in nested directories" "$f1 ($a rows)" "$f2 ($b rows)" "$f3 ($c rows)"

# Fixture 3: mixed-case extensions.
a=$(( 2 + RANDOM % 9 )); b=$(( 2 + RANDOM % 9 )); c=$(( 2 + RANDOM % 9 ))
mkcsv "$WORK/mixed/incoming/lower-$RANDOM.csv" $a;  g1=$(cd "$WORK/mixed" && ls incoming/lower-*)
mkcsv "$WORK/mixed/incoming/UPPER-$RANDOM.CSV" $b;  g2=$(cd "$WORK/mixed" && ls incoming/UPPER-*)
mkcsv "$WORK/mixed/incoming/sub/Camel-$RANDOM.Csv" $c; g3=$(cd "$WORK/mixed" && ls incoming/sub/Camel-*)
run mixed
check mixed "with .csv, .CSV and .Csv files" "$g1 ($a rows)" "$g2 ($b rows)" "$g3 ($c rows)"

# Fixture 4: summary.txt already exists and must survive.
mkcsv "$WORK/audit/incoming/new-$RANDOM.csv" 4
printf 'files=7 rows=%d   (audited, ticket AUD-%d)\n' $RANDOM $RANDOM > "$WORK/audit/summary.txt"
cp "$WORK/audit/summary.txt" "$WORK/audit.keep"
run audit
if ! cmp -s "$WORK/audit/summary.txt" "$WORK/audit.keep"; then
  echo "❌ ingest.sh overwrote an existing summary.txt; it must refuse and leave the old one alone"
  exit 1
fi
if [ "$(cat "$WORK/audit.code")" -eq 0 ]; then
  echo "❌ when summary.txt already exists, ingest.sh must exit with a non-zero status"
  exit 1
fi

echo "✅ ingest.sh handles empty, nested and mixed-case uploads and never overwrites summary.txt"
exit 0
