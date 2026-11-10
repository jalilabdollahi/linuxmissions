#!/bin/bash
# $1 = sandbox path
# restore.tar.xz (random size and member count) and the df output of six kiosk
# boxes. Each box gets one situation, shuffled on every setup:
#   roomy    /srv has the most free space, but 99% of its inodes are used
#   rootok   no /srv mount (only /srv/backup), so / counts, and / has room
#   rootno   no /srv mount, and / is too small (/srv/backup is huge)
#   tight    /srv is a few hundred KiB short (df -h would show the same size)
#   justok   /srv has a few hundred KiB more than needed
#   fine     /srv has room and inodes
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# --- the archive -------------------------------------------------------------
mkdir -p .gen/kiosk/media .gen/kiosk/config
head -c $(( (RANDOM % 20 + 38) * 1048576 )) /dev/zero > .gen/kiosk/media/loop-main.mp4
head -c $(( (RANDOM % 900 + 300) * 1024 )) /dev/urandom > .gen/kiosk/media/logo-anim.webm
printf 'screen=portrait\nidle_timeout=90\n' > .gen/kiosk/config/kiosk.ini
dirs=$(( RANDOM % 15 + 30 ))
for d in $(seq 1 $dirs); do
  dd=$(printf '%03d' "$d")
  mkdir -p ".gen/kiosk/catalog/$dd"
  for f in $(seq 1 $(( RANDOM % 40 + 80 ))); do
    printf 'sku-%s-%s thumbnail placeholder\n' "$dd" "$f" > ".gen/kiosk/catalog/$dd/$f.jpg"
  done
done
tar -cf - -C .gen kiosk | xz -1 > restore.tar.xz
rm -rf .gen

need_kib=$(( ( $(xz -dc restore.tar.xz | wc -c) + 1023 ) / 1024 ))
need_ino=$(xz -dc restore.tar.xz | tar -tf - | wc -l | tr -d ' ')

# --- df output per host --------------------------------------------------------
dfp() {  # dfp DEV TYPE SIZE AVAIL MOUNT   -> one df -PT line (5% reserved on ext4)
  local res=0 used cap
  [ "$2" = ext4 ] && res=$(( $3 / 20 ))
  used=$(( $3 - $4 - res )); [ $used -lt 0 ] && used=0
  cap=$(( (used * 100 + used + $4 - 1) / (used + $4) ))
  printf '%-15s %-8s %11d %9d %9d %7s %s\n' "$1" "$2" "$3" "$used" "$4" "$cap%" "$5"
}
dfi() {  # dfi DEV INODES IFREE MOUNT   -> one df -i line
  local iused=$(( $2 - $3 )) pct
  pct=$(( (iused * 100 + $2 - 1) / $2 ))
  printf '%-15s %8d %7d %7d %4s %s\n' "$1" "$2" "$iused" "$3" "$pct%" "$4"
}
r() { echo $(( RANDOM % ($2 - $1 + 1) + $1 )); }   # random in [a, b]

mkdir -p hosts
hosts=(kiosk-ber-01 kiosk-ham-02 kiosk-muc-03 kiosk-fra-04 kiosk-cgn-05 kiosk-stu-06)
kinds=$(printf '%s\n' roomy rootok rootno tight justok fine | while read -r k; do echo "$RANDOM $k"; done | sort -n | cut -d' ' -f2)

i=0
for kind in $kinds; do
  h=${hosts[$i]}; i=$((i + 1))
  root_size=$(r 3600000 3800000); root_avail=$(r 300000 900000); root_ino=$(r 230000 240000); root_ifree=$(r 90000 150000)
  srv_size=$(r 1900000 2000000); srv_avail=$(( need_kib * 2 + $(r 1000 90000) )); srv_ino=131072; srv_ifree=$(r 40000 110000)
  srv=yes
  case $kind in
    roomy)  srv_avail=$(( need_kib * 6 + $(r 1000 50000) )); srv_ifree=$(r 900 1300); srv_size=$(r 2600000 2800000) ;;
    rootok) srv=no; root_avail=$(( need_kib + need_kib / $(r 3 8) )) ;;
    rootno) srv=no; root_avail=$(( need_kib - need_kib / $(r 4 9) )) ;;
    tight)  srv_avail=$(( need_kib - $(r 40 300) )) ;;
    justok) srv_avail=$(( need_kib + $(r 0 300) )) ;;
    fine)   ;;
  esac
  {
    echo "# inventory snapshot of $h, 2026-11-10 06:00 UTC"
    echo '$ df -PT'
    echo 'Filesystem      Type     1024-blocks      Used Available Capacity Mounted on'
    dfp /dev/mmcblk0p2 ext4 "$root_size" "$root_avail" /
    dfp tmpfs tmpfs 401232 $(r 395000 400000) /run
    dfp tmpfs tmpfs 2006140 2006140 /dev/shm
    dfp /dev/mmcblk0p1 vfat 522224 $(r 400000 450000) /boot/firmware
    if [ $srv = yes ]; then
      dfp /dev/sda1 ext4 "$srv_size" "$srv_avail" /srv
    else
      dfp /dev/sda1 ext4 $(r 15000000 16000000) $(r 9000000 12000000) /srv/backup
    fi
    echo '$ df -i'
    echo 'Filesystem       Inodes   IUsed   IFree IUse% Mounted on'
    dfi /dev/mmcblk0p2 "$root_ino" "$root_ifree" /
    dfi tmpfs 501535 $(r 500000 501000) /run
    dfi tmpfs 501535 501534 /dev/shm
    printf '%-15s %8d %7d %7d %4s %s\n' /dev/mmcblk0p1 0 0 0 - /boot/firmware   # vfat has no inodes
    if [ $srv = yes ]; then
      dfi /dev/sda1 "$srv_ino" "$srv_ifree" /srv
    else
      dfi /dev/sda1 983040 $(r 900000 970000) /srv/backup
    fi
  } > "hosts/$h.txt"
done

cat > RESTORE-TICKET.txt <<'EOF'
The catalog restore (restore.tar.xz) must be unpacked into /srv on every
kiosk that can take it; the others get a bigger card next week.
We can't log in to the kiosks from here, so the nightly inventory snapshots
(hosts/*.txt, output of df -PT and df -i) are all we have.
EOF
