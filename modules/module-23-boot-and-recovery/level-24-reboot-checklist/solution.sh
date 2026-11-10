#!/bin/bash
cat > prereboot.sh <<'EOS'
#!/bin/bash
ROOT=${1:?usage: prereboot.sh ROOT}
fails=0
resolve() { p=$ROOT$1; n=0; while [ -L "$p" ] && [ $n -lt 40 ]; do t=$(readlink "$p"); case $t in /*) p=$ROOT$t;; *) p=$(dirname "$p")/$t;; esac; n=$((n+1)); done; [ $n -lt 40 ] && [ -e "$p" ]; }
check_grub() {
  local def two=0 k i
  def=$(sed -n 's/^set default="\(.*\)".*/\1/p' "$ROOT/boot/grub/grub.cfg" | head -n1)
  case $def in *'>'*) two=1;; esac
  read -r k i < <(awk -v d1="${def%%>*}" -v d2="${def#*>}" -v two=$two '
    /^[ \t]*submenu / { top++; insub=1; si=-1; next }
    /^[ \t]*menuentry / { if (insub) { si++; hit=(two && top==d1 && si==d2) } else { top++; hit=(!two && top==d1) }; inentry=1; next }
    /^[ \t]*}/ { if (inentry) inentry=0; else insub=0; next }
    inentry && hit && $1=="linux" { k=$2 }
    inentry && hit && $1=="initrd" { i=$2 }
    BEGIN { top=-1 }
    END { print k, i }' "$ROOT/boot/grub/grub.cfg")
  [ -n "$k" ] && [ -n "$i" ] && [ -e "$ROOT$k" ] && [ -e "$ROOT$i" ]
}
check_fstab() {
  local src rest v
  while read -r src rest; do
    case $src in
      ''|'#'*) continue ;;
      UUID=*) v=${src#UUID=}; grep -qi " UUID=\"$v\"" "$ROOT/blkid.txt" || return 1 ;;
      LABEL=*) v=${src#LABEL=}; grep -q " LABEL=\"$v\"" "$ROOT/blkid.txt" || return 1 ;;
      /dev/*) grep -q "^$src:" "$ROOT/blkid.txt" || return 1 ;;
    esac
  done < "$ROOT/etc/fstab"
}
check_target() { resolve /etc/systemd/system/default.target; }
check_boot() { local a; a=$(awk '$NF=="/boot" { gsub(/M/, "", $4); print $4 }' "$ROOT/df.txt"); [ "${a:-0}" -ge 100 ]; }
run() { if "$1"; then echo "PASS $2"; else echo "FAIL $2"; fails=$((fails+1)); fi; }
run check_grub grub-default; run check_fstab fstab-uuids; run check_target default-target; run check_boot boot-free
exit $fails
EOS
bash prereboot.sh roots/healthy; echo "exit=$?"; bash prereboot.sh roots/broken; echo "exit=$?"
