#!/bin/bash
cat > promote.sh <<'SCRIPT'
#!/bin/bash
# usage: promote.sh BUILD_DIR
here=$(cd "$(dirname "$0")" && pwd)
b=${1:?usage: promote.sh BUILD_DIR}
reject() { echo "REJECT: $*"; exit 1; }

gpgv --keyring "$here/keys/release.gpg" "$b/SHA256SUMS.sig" "$b/SHA256SUMS" >/dev/null 2>&1 || reject signature
(cd "$b" && sha256sum -c --status SHA256SUMS) >/dev/null 2>&1 || reject checksum

art=$(ls "$b"/agent-*.tar.gz 2>/dev/null | head -n 1)
ver=$(basename "$art" .tar.gz); ver=${ver#agent-}
dpkg --compare-versions "$ver" gt "$(cat "$here/prod/VERSION")" || reject version

re=$(printf '%s' "$ver" | sed 's/\./\\./g')
grep -qE "^## $re - " "$b/CHANGELOG.md" || reject changelog

list=$(tar --numeric-owner -tvzf "$art" 2>/dev/null) || reject layout
printf '%s\n' "$list" | awk -v top="agent-$ver" '
  { perm = $1; own = $2; name = $NF }
  index(name, top "/") != 1 && name != top { bad = 1 }
  own != "0/0" { bad = 1 }
  name ~ /(^|\/)\.DS_Store$/ || name ~ /\.o$/ || name ~ /~$/ { bad = 1 }
  { rel = name; sub("^" top "/?", "", rel) }
  perm ~ /^d/ { if (perm != "drwxr-xr-x") bad = 1; next }
  perm ~ /^-/ { want = "-rw-r--r--"; if (rel ~ /^bin\//) want = "-rwxr-xr-x"; else if (rel ~ /^conf\//) want = "-rw-r-----"; if (perm != want) bad = 1; next }
  { bad = 1 }
  END { exit bad }' || reject layout
echo PROMOTE
SCRIPT
chmod +x promote.sh
for b in builds/*; do echo "$b: $(./promote.sh "$b")"; done
