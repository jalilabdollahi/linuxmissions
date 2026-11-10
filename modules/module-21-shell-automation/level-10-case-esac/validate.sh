#!/bin/bash
# Builds archives of every supported type (some with upper-case extensions,
# spaces and dots in the name) from known trees, runs unpack.sh on each from a
# clean working directory, and compares the extracted tree (paths + cksum).
# Also checks that the original archive is untouched and that unsupported
# files give exit 2, a message on stderr and create nothing.
SANDBOX="$1"
SCRIPT="$SANDBOX/unpack.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ unpack.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/unpack.sh"
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

# Source trees
mkdir -p "$WORK/t1/lib" "$WORK/t2/sub dir"
printf 'alpha\n' > "$WORK/t1/a.txt"; printf 'lib code\n' > "$WORK/t1/lib/core.sh"
printf 'one\n' > "$WORK/t2/sub dir/x y.txt"; printf 'two\n' > "$WORK/t2/z.csv"
tree_sum() { (cd "$1" && find . -type f -exec cksum {} + | sort); }
tree_sum "$WORK/t1" > "$WORK/t1.sum"
tree_sum "$WORK/t2" > "$WORK/t2.sum"

mkdir "$WORK/inbox"
(cd "$WORK/t1" && tar -czf "$WORK/inbox/app-2.4.1.tar.gz" .)
(cd "$WORK/t2" && tar -czf "$WORK/inbox/fonts.tgz" .)
(cd "$WORK/t1" && tar -czf "$WORK/inbox/BACKUP.TGZ" .)
(cd "$WORK/t2" && tar -cJf "$WORK/inbox/geo data.tar.xz" .)
(cd "$WORK/t1" && zip -qr "$WORK/inbox/invoices.zip" .)
(cd "$WORK/t2" && zip -qr "$WORK/inbox/SCANS-2026.ZIP" .)
printf 'line 1\nline 2\n' | gzip -c > "$WORK/inbox/access.log.gz"
printf 'Rar!' > "$WORK/inbox/legacy.rar"
printf 'hello\n' > "$WORK/inbox/notes.txt"
(cd "$WORK/inbox" && cksum -- * | sort) > "$WORK/inbox.sum"

RUN="$WORK/run"
# run ARCHIVE: runs unpack.sh in a fresh, empty $RUN, sets CODE
run() {
  rm -rf -- "$RUN"
  mkdir "$RUN"
  (cd "$RUN" && $LIMIT bash ../unpack.sh "../inbox/$1" </dev/null >"$WORK/out" 2>"$WORK/err")
  CODE=$?
  if [ "$(cd "$WORK/inbox" && cksum -- * | sort)" != "$(cat "$WORK/inbox.sum")" ]; then
    echo "❌ ./unpack.sh '$1' changed or removed files in the inbox; the original archive must stay as it is"
    exit 1
  fi
}
listing() { ls -A "$RUN" | tr '\n' ' ' | sed 's/ $//'; }

# dir ARCHIVE NAME TREE
dir() {
  run "$1"
  if [ "$CODE" != 0 ]; then
    echo "❌ ./unpack.sh '$1' exited with $CODE ($(head -n 1 "$WORK/err")), expected 0"
    exit 1
  fi
  if [ ! -d "$RUN/$2" ]; then
    echo "❌ ./unpack.sh '$1' created [$(listing)] in the current directory, expected the directory '$2/'"
    exit 1
  fi
  if [ "$(ls -A "$RUN" | wc -l | tr -d ' ')" != 1 ]; then
    echo "❌ ./unpack.sh '$1' left more than the directory '$2/' behind: $(listing)"
    exit 1
  fi
  if [ "$(tree_sum "$RUN/$2")" != "$(cat "$WORK/$3.sum")" ]; then
    echo "❌ ./unpack.sh '$1': the files inside '$2/' are not the archive's contents"
    exit 1
  fi
}

dir "app-2.4.1.tar.gz" "app-2.4.1" t1
dir "fonts.tgz" "fonts" t2
dir "BACKUP.TGZ" "BACKUP" t1
dir "geo data.tar.xz" "geo data" t2
dir "invoices.zip" "invoices" t1
dir "SCANS-2026.ZIP" "SCANS-2026" t2

run "access.log.gz"
if [ "$CODE" != 0 ] || [ "$(listing)" != "access.log" ] || [ "$(cat "$RUN/access.log" 2>/dev/null)" != $'line 1\nline 2' ]; then
  echo "❌ ./unpack.sh access.log.gz must create just the decompressed file access.log in the current directory (exit $CODE, got: $(listing))"
  exit 1
fi

for bad in legacy.rar notes.txt; do
  run "$bad"
  if [ "$CODE" != 2 ] || [ ! -s "$WORK/err" ] || [ -s "$WORK/out" ] || [ -n "$(listing)" ]; then
    echo "❌ ./unpack.sh '$bad' must print its message on stderr, create nothing and exit 2 (got exit $CODE)"
    exit 1
  fi
done

echo "✅ unpack.sh picks the right branch for every archive type, in any letter case, and rejects the rest"
exit 0
