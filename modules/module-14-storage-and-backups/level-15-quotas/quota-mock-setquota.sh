#!/bin/bash
# Mock setquota for the NAS quota level (a real one needs root and a quota-enabled
# file system). Same argument layout as the real tool:
#   setquota [-u] USER block-softlimit block-hardlimit inode-softlimit inode-hardlimit FILESYSTEM
# Block limits are in KiB (1 KiB blocks), inode limits are counts; 0 means no limit.
DB="$(cd "$(dirname "$0")/.." && pwd)/.lm-state/quota.db"
FS=/srv/nas; DEV=/dev/mapper/vg0-nas
usage() {
  echo "setquota: Bad number of arguments." >&2
  echo "setquota [-u|-g|-P] [-F quotaformat] <user|group|project>" >&2
  echo "	<block-softlimit> <block-hardlimit> <inode-softlimit> <inode-hardlimit> -a|<filesystem>..." >&2
  exit 1
}
args=()
for a in "$@"; do
  case "$a" in
    -u|--user) ;;
    -g|-P|--group|--project) echo "setquota: only user quotas are enabled on $FS" >&2; exit 1 ;;
    -a|--all) echo "setquota: -a is not supported by this mock; name the file system" >&2; exit 1 ;;
    -*) echo "setquota: unsupported option $a" >&2; exit 1 ;;
    *) args+=("$a") ;;
  esac
done
[ "${#args[@]}" -eq 6 ] || usage
user=${args[0]}; bs=${args[1]}; bh=${args[2]}; is=${args[3]}; ih=${args[4]}; fs=${args[5]}
for n in "$bs" "$bh" "$is" "$ih"; do
  case "$n" in ''|*[!0-9]*) echo "setquota: Illegal number $n" >&2; exit 1 ;; esac
done
if [ "$fs" != "$FS" ] && [ "$fs" != "$DEV" ]; then
  echo "setquota: Mountpoint (or device) $fs not found or has no quota enabled." >&2
  echo "setquota: Maybe you forgot to run quotacheck?" >&2
  exit 1
fi
grep -q "^$user " "$DB" || { echo "setquota: Cannot find user '$user' in the quota database." >&2; exit 1; }
if [ "$bs" -gt 0 ] && [ "$bh" -gt 0 ] && [ "$bs" -gt "$bh" ]; then
  echo "setquota: block soft limit is larger than the hard limit" >&2; exit 1
fi
tmp=$(mktemp "$DB.XXXXXX")
while read -r u bu obs obh bg iu ois oih ig; do
  if [ "$u" = "$user" ]; then
    # recompute grace: cleared when no longer over a limit, started (7days) when newly over
    over_b=0; { [ "$bs" -gt 0 ] && [ "$bu" -gt "$bs" ]; } || { [ "$bh" -gt 0 ] && [ "$bu" -ge "$bh" ]; } && over_b=1
    over_i=0; { [ "$is" -gt 0 ] && [ "$iu" -gt "$is" ]; } || { [ "$ih" -gt 0 ] && [ "$iu" -ge "$ih" ]; } && over_i=1
    if [ $over_b = 0 ]; then bg=-; elif [ "$bg" = "-" ]; then bg=7days; fi
    if [ $over_i = 0 ]; then ig=-; elif [ "$ig" = "-" ]; then ig=7days; fi
    echo "$u $bu $bs $bh $bg $iu $is $ih $ig"
  else
    echo "$u $bu $obs $obh $bg $iu $ois $oih $ig"
  fi
done < "$DB" > "$tmp" && mv "$tmp" "$DB"
