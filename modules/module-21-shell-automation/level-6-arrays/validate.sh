#!/bin/bash
# Runs upload_batch.sh with a validator-owned upload mock (one log line per
# call, <arg> per argument, refuses >4 files) on the shipped manifest and on
# manifests the player has not seen, and compares the call log line by line
# plus the final "uploaded N files" line.
SANDBOX="$1"
SCRIPT="$SANDBOX/upload_batch.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ upload_batch.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/tools"
cp "$SCRIPT" "$WORK/upload_batch.sh"
cat > "$WORK/tools/upload" <<'EOF'
#!/bin/bash
printf '<%s>' "$@" >> calls.log
echo >> calls.log
[ "$#" -le 4 ] || exit 1
EOF
chmod +x "$WORK/tools/upload"
cd "$WORK" || exit 1
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# check LABEL MANIFEST EXPECTED-CALLS-FILE COUNT
check() {
  rm -f calls.log
  touch calls.log
  $LIMIT bash ./upload_batch.sh "$2" </dev/null >out 2>err
  if ! diff -q calls.log "$3" >/dev/null; then
    line=$(diff "$3" calls.log | grep -m1 '^[<>]')
    n=$(wc -l < calls.log | tr -d ' ')
    w=$(wc -l < "$3" | tr -d ' ')
    if [ "$n" != "$w" ]; then
      echo "❌ $1: upload was called $n time(s), expected $w (first difference: ${line:0:150})"
    else
      echo "❌ $1: an upload call differs. Expected '$(diff "$3" calls.log | grep -m1 '^<' | cut -c3-150)', got '$(diff "$3" calls.log | grep -m1 '^>' | cut -c3-150)'"
    fi
    exit 1
  fi
  if [ "$(tail -n 1 out)" != "uploaded $4 files" ]; then
    echo "❌ $1: last line was '$(tail -n 1 out)', expected 'uploaded $4 files'"
    exit 1
  fi
}

# 1. the shipped manifest (fresh copy)
printf '%s\n' 'media/banner.png' 'media/Q3 report.pdf' '' 'media/team photo  (final).jpg' 'media/logo.svg' '' '' \
  'media/menu autumn.pdf' 'media/contract v2.docx' > shipped.txt
printf '%s\n' '<media/banner.png><media/Q3 report.pdf><media/team photo  (final).jpg><media/logo.svg>' \
  '<media/menu autumn.pdf><media/contract v2.docx>' > shipped.want
check "manifest.txt" shipped.txt shipped.want 6

# 2. nine files: batches of 4, 4, 1, with glob characters and a backslash
touch a.jpg b.jpg
printf '%s\n' '' 'press kit/cover.png' '*.jpg' 'two  spaces.txt' 'back\slash.txt' '' 'tab	inside.txt' \
  'x [draft].doc' '' 'final.pdf' '-dash.txt' 'end of list.zip' > nine.txt
printf '%s\n' '<press kit/cover.png><*.jpg><two  spaces.txt><back\slash.txt>' \
  '<tab	inside.txt><x [draft].doc><final.pdf><-dash.txt>' '<end of list.zip>' > nine.want
check "a manifest with 9 names" nine.txt nine.want 9

# 3. exactly four names: one call
printf '%s\n' 'one.txt' 'two words.txt' 'three.txt' 'four  four.txt' > four.txt
printf '%s\n' '<one.txt><two words.txt><three.txt><four  four.txt>' > four.want
check "a manifest with exactly 4 names" four.txt four.want 4

# 4. only empty lines: no call at all
printf '\n\n\n' > blank.txt
: > blank.want
check "a manifest with only empty lines" blank.txt blank.want 0

echo "✅ upload_batch.sh keeps every name intact, skips empty lines and sends batches of at most 4"
exit 0
