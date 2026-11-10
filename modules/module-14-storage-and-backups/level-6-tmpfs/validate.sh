#!/bin/bash
# fstab: exactly one /tmp entry, a tmpfs with the options size=<ticket>,mode=1777,
# nosuid,nodev and nothing else, pass 0; every other line unchanged.
# shm.txt: the size of /dev/shm in KiB as df -k reports it.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
. .lm-state/spec

[ -f etc/fstab ] || { echo "❌ etc/fstab is missing"; exit 1; }

tobytes() {  # 2G, 2048M, 512m, 524288k, 1073741824 -> bytes
  awk -v v="$1" 'BEGIN {
    if (match(v, /^[0-9]+[kKmMgG]?$/) == 0) { print "bad"; exit }
    n = v + 0; u = tolower(substr(v, length(v), 1))
    if (u == "k") n *= 1024; else if (u == "m") n *= 1048576; else if (u == "g") n *= 1073741824
    printf "%d\n", n }'
}

# everything but the /tmp lines must be as before
strip() { grep -v '^[[:space:]]*$' "$1" | awk '!/^[[:space:]]*#/ && $2 == "/tmp" { next } { print }'; }
if [ "$(strip etc/fstab)" != "$(strip .lm-state/orig.fstab)" ]; then
  echo "❌ some other line of etc/fstab (or a comment) was changed or removed; only the /tmp line should differ"
  exit 1
fi

lines=$(awk '!/^[[:space:]]*#/ && $2 == "/tmp"' etc/fstab)
n=$(printf '%s\n' "$lines" | grep -c .)
if [ "$n" -eq 0 ]; then echo "❌ etc/fstab has no entry for /tmp"; exit 1; fi
if [ "$n" -gt 1 ]; then echo "❌ etc/fstab has $n entries for /tmp: the old disk line has to be removed"; exit 1; fi
set -- $lines
if [ $# -ne 6 ]; then echo "❌ the /tmp entry does not have six fields: $lines"; exit 1; fi
dev=$1; type=$3; opts=$4; pass=$6
if [ "$type" != tmpfs ]; then echo "❌ /tmp is still of type $type, it must be tmpfs"; exit 1; fi
if [ "$dev" != tmpfs ]; then echo "❌ the device field of a tmpfs entry is the word tmpfs, not '$dev'"; exit 1; fi

has_sizes=0; mode_ok=0; nosuid=0; nodev=0
for o in $(printf '%s' "$opts" | tr ',' ' '); do
  case "$o" in
    size=*)
      has_sizes=1
      if [ "$(tobytes "${o#size=}")" != "$(tobytes "$SIZE")" ]; then
        echo "❌ the size limit is ${o#size=}, the ticket asks for $SIZE"; exit 1
      fi ;;
    mode=1777) mode_ok=1 ;;
    mode=*) echo "❌ $o: /tmp must be mode=1777 (world-writable with the sticky bit)"; exit 1 ;;
    nosuid) nosuid=1 ;;
    nodev) nodev=1 ;;
    noexec) echo "❌ noexec on /tmp: the build runs the binaries it compiles there (the ticket says so)"; exit 1 ;;
    defaults) echo "❌ 'defaults' is not on the ticket's list: use exactly size, mode, nosuid and nodev"; exit 1 ;;
    *) echo "❌ the option '$o' is not asked for: use exactly size, mode, nosuid and nodev"; exit 1 ;;
  esac
done
[ $has_sizes = 1 ] || { echo "❌ no size= limit: an unbounded tmpfs may take half of the RAM"; exit 1; }
[ $mode_ok = 1 ] || { echo "❌ no mode=1777: the permissions of /tmp (world-writable plus the sticky bit) must be stated explicitly, so nothing depends on a default"; exit 1; }
[ $nosuid = 1 ] || { echo "❌ nosuid is missing from the /tmp options"; exit 1; }
[ $nodev = 1 ] || { echo "❌ nodev is missing from the /tmp options"; exit 1; }
[ "$pass" = 0 ] || { echo "❌ the pass column of a tmpfs must be 0: there is nothing to fsck"; exit 1; }

if [ ! -f shm.txt ]; then echo "❌ shm.txt does not exist yet"; exit 1; fi
kib=$(df -Pk /dev/shm 2>/dev/null | awk 'NR == 2 { print $2 }')
if [ -z "$kib" ]; then echo "❌ the checker cannot read /dev/shm on this machine"; exit 1; fi
got=$(tr -d '\r' < shm.txt | awk 'NF' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
if ! [[ $got =~ ^[0-9]+$ ]]; then
  echo "❌ shm.txt must hold a plain number of KiB, without a unit or other text"
  exit 1
fi
if [ "$got" != "$kib" ]; then
  if [ "$got" = $((kib * 1024)) ]; then echo "❌ shm.txt looks like bytes; the number must be KiB (1024 bytes)"
  elif [ "$got" = $((kib / 1024)) ]; then echo "❌ shm.txt looks like MiB; the number must be KiB"
  else echo "❌ shm.txt does not match the size of /dev/shm on this machine"; fi
  exit 1
fi
echo "✅ /tmp is a tmpfs with exactly the required options, and shm.txt matches /dev/shm"
exit 0
