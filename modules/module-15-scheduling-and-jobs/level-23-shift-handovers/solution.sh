#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
cat > inventory.sh <<'EOF'
#!/bin/bash
out=inventory.tsv
: > "$out"
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$out"; }

# crontabs: $1 = file, $2 = user (empty = read the user from the 6th field)
crontab_rows() {
  local line a b c d e u rest
  while IFS= read -r line; do
    line=${line#"${line%%[![:space:]]*}"}
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in [A-Za-z_]*=*) continue ;; esac
    if [ "${line:0:1}" = "@" ]; then
      if [ -n "$2" ]; then read -r a rest <<< "$line"; u=$2
      else read -r a u rest <<< "$line"; fi
      emit "$1" "$u" "$a" "$rest"
    else
      if [ -n "$2" ]; then read -r a b c d e rest <<< "$line"; u=$2
      else read -r a b c d e u rest <<< "$line"; fi
      emit "$1" "$u" "$a $b $c $d $e" "$rest"
    fi
  done < "$1"
}

for f in var/spool/cron/crontabs/*; do crontab_rows "$f" "$(basename "$f")"; done
crontab_rows etc/crontab ""
for f in etc/cron.d/*; do
  case "$(basename "$f")" in *[!A-Za-z0-9_-]*) continue ;; esac
  crontab_rows "$f" ""
done

# enabled timers are the ones linked into timers.target.wants
for l in etc/systemd/system/timers.target.wants/*.timer; do
  t=$(basename "$l")
  file=etc/systemd/system/$t
  cal=$(sed -n 's/^OnCalendar=//p' "$file" | head -n 1)
  unit=$(sed -n 's/^Unit=//p' "$file" | head -n 1)
  svc=etc/systemd/system/${unit:-${t%.timer}.service}
  user=$(sed -n 's/^User=//p' "$svc" | head -n 1)
  emit "$file" "${user:-root}" "$cal" "$(sed -n 's/^ExecStart=//p' "$svc" | head -n 1)"
done

# the at queue
atq | while IFS=$'\t' read -r id rest; do
  when=$(echo "$rest" | awk '{print $1, $2, $3, $4, $5}')
  user=$(echo "$rest" | awk '{print $NF}')
  emit "at:$id" "$user" "$(date -d "$when" '+%Y-%m-%d %H:%M')" "$(at -c "$id" | tail -n 1)"
done
EOF
bash inventory.sh
