#!/bin/bash
# Mock repquota for the NAS quota level (not a real quota system): prints the
# user quota report from the mock database in the real repquota layout.
# Supported: repquota -a | repquota [-u] [-v] [-s no] /srv/nas
DB="$(cd "$(dirname "$0")/.." && pwd)/.lm-state/quota.db"
FS=/srv/nas; DEV=/dev/mapper/vg0-nas
all=0; target=""
for a in "$@"; do
  case "$a" in
    -a|--all) all=1 ;;
    -u|-v|-n|-c|-C|--user|--verbose) ;;
    -g|-P|--group|--project) echo "repquota: only user quotas are enabled on $FS" >&2; exit 1 ;;
    -*) echo "repquota: unsupported option $a" >&2; exit 1 ;;
    *) target=$a ;;
  esac
done
if [ "$all" = 0 ] && [ -z "$target" ]; then
  echo "Utility for printing current state of quota. Usage:" >&2
  echo "  repquota [-vugsiapcC] [-t|-n] [-F quotaformat] (mountpoint|-a)" >&2
  exit 1
fi
if [ "$all" = 0 ] && [ "$target" != "$FS" ] && [ "$target" != "$DEV" ]; then
  echo "repquota: Mountpoint (or device) $target not found or has no quota enabled." >&2
  echo "repquota: Not all specified mountpoints are using quota." >&2
  exit 1
fi
[ -f "$DB" ] || { echo "repquota: Cannot open quotafile $FS/aquota.user: No such file or directory" >&2; exit 1; }
echo "*** Report for user quotas on device $DEV"
echo "Block grace time: 7days; Inode grace time: 7days"
echo "                        Block limits                File limits"
echo "User            used    soft    hard  grace    used  soft  hard  grace"
echo "----------------------------------------------------------------------"
while read -r u bu bs bh bg iu is ih ig; do
  [ -n "$u" ] || continue
  f1=-; f2=-
  { [ "$bs" -gt 0 ] && [ "$bu" -gt "$bs" ]; } || { [ "$bh" -gt 0 ] && [ "$bu" -ge "$bh" ]; } && f1=+
  { [ "$is" -gt 0 ] && [ "$iu" -gt "$is" ]; } || { [ "$ih" -gt 0 ] && [ "$iu" -ge "$ih" ]; } && f2=+
  [ "$bg" = "-" ] && bg=""; [ "$ig" = "-" ] && ig=""
  printf '%-9s %s%s %8d %7d %7d %7s %7d %5d %5d %7s\n' "$u" "$f1" "$f2" "$bu" "$bs" "$bh" "$bg" "$iu" "$is" "$ih" "$ig"
done < "$DB"
echo
