#!/bin/bash
# Runs make_tag.sh in scratch checkouts with a mock git: two good runs (CRLF
# VERSION with a fixed TAG_DATE, plain VERSION with today's date) and four bad
# ones (git fails with and without an older release.tag, VERSION missing,
# VERSION empty). Good runs must write the exact tag; bad runs must exit
# non-zero, say why on stderr and leave release.tag alone.
SANDBOX="$1"
SCRIPT="$SANDBOX/make_tag.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ make_tag.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

mkdir -p "$WORK/bin"
cat > "$WORK/bin/git" <<'MOCK'
#!/bin/bash
if [ "$1" = rev-parse ] && [ "${!#}" = HEAD ] && [ -f .mockgit/HEAD ]; then
  sha="$(cat .mockgit/HEAD)"
  if [ "$2" = --short ]; then echo "${sha:0:7}"; else echo "$sha"; fi
  exit 0
fi
echo "fatal: not a git repository (or any of the parent directories): .git" >&2
exit 128
MOCK
chmod +x "$WORK/bin/git"

hex40() { local s=""; while [ ${#s} -lt 40 ]; do s="$s$(printf '%04x' $RANDOM)"; done; echo "${s:0:40}"; }

# checkout NAME VERSION_BYTES(printf format, or "-" for no file) WITH_GIT(yes/no) OLD_TAG
checkout() {
  D="$WORK/$1"
  mkdir -p "$D"
  cp "$SCRIPT" "$D/make_tag.sh"
  [ "$2" != "-" ] && printf "$2" > "$D/VERSION"
  if [ "$3" = yes ]; then mkdir -p "$D/.mockgit"; SHA="$(hex40)"; echo "$SHA" > "$D/.mockgit/HEAD"; fi
  [ -n "$4" ] && echo "$4" > "$D/release.tag"
}
# run [VAR=value...]: run make_tag.sh in $D like CI does
run() {
  (cd "$D" && $LIMIT env "$@" PATH="$WORK/bin:$PATH" bash ./make_tag.sh </dev/null >"$D/.out" 2>"$D/.err")
  CODE=$?
}

# 1. good run, CRLF VERSION, fixed date
day=$(( 20260101 + RANDOM % 28 ))
checkout good1 '1.2.0\r\n' yes ""
run TAG_DATE="$day"
want="app-1.2.0-${SHA:0:7}-$day"
if [ "$CODE" != 0 ]; then
  echo "❌ with a working git, make_tag.sh failed (status $CODE): $(head -1 "$D/.err")"
  exit 1
fi
if [ ! -f "$D/release.tag" ]; then
  echo "❌ with a working git, make_tag.sh did not write release.tag"
  exit 1
fi
if [ "$(cat "$D/release.tag")" != "$want" ] || [ "$(wc -l < "$D/release.tag" | tr -d ' ')" != 1 ]; then
  if LC_ALL=C grep -q "$(printf '\r')" "$D/release.tag"; then
    echo "❌ release.tag contains a carriage return (\\r): VERSION ends in CRLF, strip it"
  else
    echo "❌ release.tag is '$(head -1 "$D/release.tag")', expected '$want' (TAG_DATE=$day)"
  fi
  exit 1
fi

# 2. good run, plain VERSION, no TAG_DATE: today's date
checkout good2 '2.0.0-rc.1\n' yes ""
run -u TAG_DATE
want="app-2.0.0-rc.1-${SHA:0:7}-$(date +%Y%m%d)"
if [ "$CODE" != 0 ] || [ "$(cat "$D/release.tag" 2>/dev/null)" != "$want" ]; then
  echo "❌ without TAG_DATE, release.tag should be '$want' (today's date), got '$(head -1 "$D/release.tag" 2>/dev/null)' (status $CODE)"
  exit 1
fi

# bad CASE_TEXT: the last run must have failed cleanly
bad() {
  if [ "$CODE" = 0 ]; then
    echo "❌ $1: make_tag.sh still exits 0"
    exit 1
  fi
  if [ -n "$OLD" ]; then
    if [ "$(cat "$D/release.tag" 2>/dev/null)" != "$OLD" ]; then
      echo "❌ $1: make_tag.sh overwrote the previous release.tag; build the whole tag first, write the file only when it is complete"
      exit 1
    fi
  elif [ -e "$D/release.tag" ]; then
    echo "❌ $1: make_tag.sh exits $CODE but still writes release.tag ('$(head -1 "$D/release.tag")')"
    exit 1
  fi
  if [ ! -s "$D/.err" ]; then
    echo "❌ $1: make_tag.sh fails without saying why on stderr"
    exit 1
  fi
}

# 3. git fails, an older tag is there
OLD="app-1.1.9-8c41d07-20261020"
checkout nogit1 '1.2.0\r\n' no "$OLD"
run TAG_DATE=20261110
bad "when git fails (not a repository)"

# 4. git fails, no older tag
OLD=""
checkout nogit2 '1.2.0\n' no ""
run TAG_DATE=20261110
bad "when git fails (not a repository)"

# 5. VERSION missing
checkout noversion - yes ""
run TAG_DATE=20261110
bad "when the VERSION file is missing"

# 6. VERSION empty (only a CRLF)
checkout emptyversion '\r\n' yes ""
run TAG_DATE=20261110
bad "when the VERSION file is empty"

echo "✅ make_tag.sh writes the exact tag, and stops without a tag when git or VERSION fails"
exit 0
