#!/bin/bash
# Runs publish.sh twice on fixtures with a slow tar (it writes half the archive,
# pauses, writes the rest): first killed in the pause, then to completion.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -f publish.sh ] || { echo "❌ publish.sh is missing"; exit 1; }

REAL_TAR=$(command -v tar); REAL_MV=$(command -v mv); REAL_SYNC=$(command -v sync)
W=$(mktemp -d "$SANDBOX/.lm-state/val.XXXXXX") || exit 1
T=$(mktemp -d /dev/shm/lm9.XXXXXX 2>/dev/null) || { T="$W/tmp"; mkdir -p "$T"; }
cleanup() { pkill -9 -f "$W" 2>/dev/null; rm -rf "$W" "$T"; }
trap cleanup EXIT
mkdir -p "$W/bin" "$W/src/sub" "$W/dest" "$W/old"
export LM_REAL_TAR="$REAL_TAR" LM_LOG="$W/log" LM_MARK="$W/mark" LM_WORK="$W"

cat > "$W/bin/tar" <<'EOF'
#!/bin/bash
# slow tar: build the archive for real, then deliver half of it, pause, deliver the rest
args=("$@"); out=""; idx=-1; eq=0; n=${#args[@]}
for ((i = 0; i < n; i++)); do
  a=${args[i]}
  case "$a" in
    --file=*) out=${a#--file=}; idx=$i; eq=1 ;;
    --file|-f) out=${args[i+1]}; idx=$((i + 1)) ;;
    --*) ;;
    -[a-zA-Z]*f*) out=${args[i+1]}; idx=$((i + 1)) ;;
    [a-zA-Z]*f*) if [ "$i" -eq 0 ]; then out=${args[i+1]}; idx=$((i + 1)); fi ;;
  esac
done
tmpf=$(mktemp "$LM_WORK/tar.XXXXXX")
if [ -z "$out" ] || [ "$out" = - ]; then
  "$LM_REAL_TAR" "$@" > "$tmpf"
  echo "tar-out stdout" >> "$LM_LOG"
  half=$(( $(stat -c %s "$tmpf") / 2 ))
  head -c "$half" "$tmpf"; : > "$LM_MARK"; sleep "${LM_SLOW:-1}"; tail -c +$((half + 1)) "$tmpf"
else
  if [ "$eq" = 1 ]; then args[idx]="--file=$tmpf"; else args[idx]=$tmpf; fi
  "$LM_REAL_TAR" "${args[@]}"
  echo "tar-out $out" >> "$LM_LOG"
  half=$(( $(stat -c %s "$tmpf") / 2 ))
  head -c "$half" "$tmpf" > "$out"
  : > "$LM_MARK"; sleep "${LM_SLOW:-1}"; tail -c +$((half + 1)) "$tmpf" >> "$out"
fi
rm -f "$tmpf"
EOF
printf '#!/bin/bash\necho "sync $*" >> "$LM_LOG"\nexec %s "$@"\n' "$REAL_SYNC" > "$W/bin/sync"
printf '#!/bin/bash\necho "mv $*" >> "$LM_LOG"\nexec %s "$@"\n' "$REAL_MV" > "$W/bin/mv"
chmod +x "$W/bin/"*

fixture() {  # dir
  mkdir -p "$1/sub"
  for f in a.html b.css sub/c.js "sub/d e.txt"; do head -c $((3000 + RANDOM)) /dev/urandom | base64 > "$1/$f"; done
}
fixture "$W/old"; fixture "$W/src"
"$REAL_TAR" -czf "$W/dest/latest.tar.gz" -C "$W/old" .
cp "$W/dest/latest.tar.gz" "$W/dest/release-old.tar.gz"
chmod 644 "$W/dest/"*.tar.gz
cp "$W/dest/latest.tar.gz" "$W/old.tar.gz"
baseline=$(ls -A "$W/dest" | sort)

launch() {  # slow-seconds
  rm -f "$LM_MARK" "$LM_LOG"
  ( env PATH="$W/bin:$PATH" TMPDIR="$T" SRC="$W/src" DEST="$W/dest" LM_SLOW="$1" bash "$SANDBOX/publish.sh" ) >/dev/null 2>&1 &
  PUB=$!
}

# 1) kill in the middle of the archive step
launch 30
for i in $(seq 1 100); do [ -e "$LM_MARK" ] && break; kill -0 "$PUB" 2>/dev/null || break; sleep 0.1; done
if [ ! -e "$LM_MARK" ]; then
  wait "$PUB" 2>/dev/null
  echo "❌ publish.sh never reached the archive step with the tar found through PATH (does it still run, and does it call plain 'tar'?)"
  exit 1
fi
sleep 0.2
if [ ! -f "$W/dest/latest.tar.gz" ]; then
  verdict="❌ while the new archive was being written latest.tar.gz did not exist at all: downloads would fail"
elif ! cmp -s "$W/dest/latest.tar.gz" "$W/old.tar.gz"; then
  verdict="❌ interrupted half-way, latest.tar.gz is a broken half-written archive: build the new one under another name and rename it into place"
elif [ -n "$(find "$T" -type f -size +0 2>/dev/null | head -1)" ]; then
  verdict="❌ the temporary file is in TMPDIR, another file system: mv across file systems is a copy, not an atomic rename; create it in the destination directory"
else
  verdict=""
fi
tarout=$(sed -n 's/^tar-out //p' "$LM_LOG" | head -1)
pkill -9 -f "$W" 2>/dev/null; kill -9 "$PUB" 2>/dev/null; wait "$PUB" 2>/dev/null
[ -z "$verdict" ] || { echo "$verdict"; exit 1; }
if [ -n "$tarout" ] && [ "$tarout" != stdout ]; then
  if [ "$(realpath -m "$tarout")" = "$(realpath -m "$W/dest/latest.tar.gz")" ]; then
    echo "❌ tar writes straight to latest.tar.gz"; exit 1
  fi
  if [ "$(dirname "$(realpath -m "$tarout")")" != "$(realpath -m "$W/dest")" ]; then
    echo "❌ the temporary file is not in the same directory as latest.tar.gz, so the final mv would not be an atomic rename"; exit 1
  fi
fi

# 2) a normal run must publish the complete new archive
find "$W/dest" -mindepth 1 -maxdepth 1 | while read -r f; do
  case "$(basename "$f")" in latest.tar.gz|release-old.tar.gz) ;; *) rm -rf "$f" ;; esac
done
cp "$W/old.tar.gz" "$W/dest/latest.tar.gz"; chmod 644 "$W/dest/latest.tar.gz"
launch 0.3
for i in $(seq 1 100); do kill -0 "$PUB" 2>/dev/null || break; sleep 0.1; done
if kill -0 "$PUB" 2>/dev/null; then pkill -9 -f "$W"; echo "❌ publish.sh does not finish"; exit 1; fi
wait "$PUB"; code=$?
if [ "$code" -ne 0 ]; then echo "❌ publish.sh exits with status $code on a normal run"; exit 1; fi
mkdir -p "$W/check"
if ! "$REAL_TAR" -xzf "$W/dest/latest.tar.gz" -C "$W/check" 2>/dev/null || ! diff -r "$W/src" "$W/check" >/dev/null 2>&1; then
  echo "❌ after a normal run latest.tar.gz is not a complete archive of the new content"
  exit 1
fi
if [ "$(ls -A "$W/dest" | sort)" != "$baseline" ]; then
  echo "❌ publish.sh leaves a temporary file behind in the destination directory after a normal run"
  exit 1
fi
mode=$(stat -c %a "$W/dest/latest.tar.gz")
if [ "$mode" != 644 ]; then
  echo "❌ latest.tar.gz has mode $mode after publishing: it must stay 644 so the web server can read it (mktemp creates private files)"
  exit 1
fi
syncl=$(grep -n '^sync' "$LM_LOG" | head -1 | cut -d: -f1)
mvl=$(grep -n '^mv' "$LM_LOG" | head -1 | cut -d: -f1)
if [ -z "$mvl" ]; then echo "❌ the new archive is never moved into place with mv (called by its plain name)"; exit 1; fi
if [ -z "$syncl" ] || [ "$syncl" -gt "$mvl" ]; then
  echo "❌ the new archive is renamed into place before it is synced to disk: after a power cut the public name could point to an empty file"
  exit 1
fi
echo "✅ latest.tar.gz is always a complete archive: temp file in the same directory, synced, then renamed"
exit 0
