#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mk() {  # path size-in-KB  (random data, so filesystems cannot compress it away)
  mkdir -p "$(dirname "$1")"
  head -c "$(( $2 * 1024 ))" /dev/urandom > "$1"
}

# The biggest directory: 30 journal files of 160 KB (4.8 MB in total)
for i in $(seq -w 1 30); do
  mk "var/log/journal/system@0000$i.journal" 160
done

# Big single files, close in size
mk srv/db/dump-2024-03.sql 1500
mk tmp/core.18342 1450
mk home/bob/.local/share/Trash/files/old-vm.img 1620
mk home/alice/videos/standup-recording.mp4 980
mk var/cache/apt/archives/linux-firmware.deb 1210

# Smaller noise
mk var/cache/apt/archives/curl.deb 180
mk var/cache/apt/archives/vim.deb 420
mk opt/app/lib/libcore.so 640
mk opt/app/lib/libnet.so 210
mk home/alice/photos/IMG_0412.jpg 350
mk home/alice/photos/IMG_0413.jpg 360
mk srv/www/static/bundle.js 75
for i in 1 2 3 4 5 6; do mk "home/alice/docs/report-$i.pdf" 40; done
