#!/bin/bash
# Most specific patterns first, case-insensitive matching, the names cut
# with ${base%.*}, the original never touched, unknown types exit 2.
cat > unpack.sh <<'SCRIPT'
#!/bin/bash
# unpack.sh FILE - extract a vendor delivery into the current directory.
f=$1
base=${f##*/}
shopt -s nocasematch

case $base in
  *.tar.gz|*.tar.xz)
    name=${base%.*}; name=${name%.*}
    mkdir -p "$name" && tar -xf "$f" -C "$name"
    ;;
  *.tgz)
    name=${base%.*}
    mkdir -p "$name" && tar -xzf "$f" -C "$name"
    ;;
  *.zip)
    unzip -q "$f" -d "${base%.*}"
    ;;
  *.gz)
    gunzip -c "$f" > "${base%.*}"
    ;;
  *)
    echo "unpack: unsupported file: $f" >&2
    exit 2
    ;;
esac
SCRIPT
mkdir -p try && cd try && ../unpack.sh ../inbox/report-tool-3.1.tar.gz && ls -R
