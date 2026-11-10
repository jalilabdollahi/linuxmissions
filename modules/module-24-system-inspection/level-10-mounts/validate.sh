#!/bin/bash
# mount.txt: "target source fstype options" of the mount in effect for
# /var/lib/ci/work/build-42: the later (bind) mount, source with [root].
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -s capture/mountinfo ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f mount.txt ] || { echo "❌ mount.txt does not exist yet"; exit 1; }
n=$(tr -d '\r' < mount.txt | grep -c .)
[ "$n" -eq 1 ] || { echo "❌ mount.txt must hold exactly one line (it has $n)"; exit 1; }
got=$(tr -d '\r' < mount.txt | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' | grep .)
want=$(cat .lm-state/expected)
alt="${want%% *} $(cut -d' ' -f2,3 <<< "$want") $(cat .lm-state/alt)"
if [ "$got" = "$want" ] || [ "$got" = "$alt" ]; then
  echo "✅ build-42 lives on the bind mount at /var/lib/ci/work, mounted noexec"; exit 0
fi
set -- $got
if [ $# -ne 4 ]; then echo "❌ the line needs four fields: target source fstype options"; exit 1; fi
[ "$1" = "$(cut -d' ' -f1 <<< "$want")" ] || { echo "❌ target $1 is not the mount that contains the path (find the longest matching mount point, on a path boundary)"; exit 1; }
src=$(cut -d' ' -f2 <<< "$want")
if [ "$2" != "$src" ]; then
  case $2 in
    "${src%%[*}") echo "❌ source is missing the part of the device that was bind-mounted (the root field of mountinfo, shown in [brackets] by findmnt)";;
    /dev/mapper/vg0-ci) echo "❌ source /dev/mapper/vg0-ci is the earlier mount at that place; a later mount hides it";;
    *) echo "❌ source $2 is not the source of the mount in effect";;
  esac
  exit 1
fi
[ "$3" = ext4 ] || { echo "❌ fstype $3 is wrong"; exit 1; }
case $4 in
  *noexec*) echo "❌ the options are not the ones of that mount (use the mount's own options, in the order mountinfo lists them)";;
  *)        echo "❌ the options $4 do not include noexec, so they are not the options of the mount in effect";;
esac
exit 1
