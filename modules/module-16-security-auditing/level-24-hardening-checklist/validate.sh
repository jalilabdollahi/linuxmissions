#!/bin/bash
# Checks the 12 points of CHECKLIST.md one by one and reports the number of the first point
# that fails. All twelve are always checked, so a fix may not break an item that was fine.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCK="$(cd "$(dirname "$0")/../../../mocks/security" && pwd)/sshd"
I=image
[ -s .lm-state/sshd.base ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -d $I ] || { echo "❌ image/ is missing"; exit 1; }
m() { stat -c %a "$1" 2>/dev/null; }

sshd_ok() {   # valid config, other settings unchanged
  python3 "$MOCK" -t -f $I/etc/ssh/sshd_config >/dev/null 2>&1 || return 1
  python3 "$MOCK" -T -f $I/etc/ssh/sshd_config 2>/dev/null | grep -vE '^(permitrootlogin|passwordauthentication|maxauthtries) ' | cmp -s - .lm-state/sshd.base || return 1
  python3 "$MOCK" -T -f $I/etc/ssh/sshd_config -C user=deploy,host=ci,addr=192.0.2.10 2>/dev/null | grep -vE '^(permitrootlogin|passwordauthentication|maxauthtries) ' | cmp -s - .lm-state/sshd.base.deploy
}
eff() {  # keyword -> effective value for the global config and for user deploy; prints both
  python3 "$MOCK" -T -f $I/etc/ssh/sshd_config 2>/dev/null | awk -v k="$1" '$1 == k { print $2 }'
  python3 "$MOCK" -T -f $I/etc/ssh/sshd_config -C user=deploy,host=ci,addr=192.0.2.10 2>/dev/null | awk -v k="$1" '$1 == k { print $2 }'
}
item1() { sshd_ok && [ "$(eff permitrootlogin | sort -u)" = no ]; }
item2() { sshd_ok && [ "$(eff passwordauthentication | sort -u)" = no ]; }
item3() { sshd_ok || return 1; local v; for v in $(eff maxauthtries); do [ "$v" -le 4 ] || return 1; done; [ -n "$(eff maxauthtries)" ]; }
item4() {
  local n=0 k
  for k in $I/etc/ssh/ssh_host_*_key; do [ -f "$k" ] || continue; n=$((n + 1)); [ "$(m "$k")" = 600 ] || return 1; done
  [ $n -ge 2 ] || return 1
  for k in $I/etc/ssh/ssh_host_*_key.pub; do [ "$(m "$k")" = 644 ] || return 1; done
}
item5() { [ "$(m $I/home/admin/.ssh)" = 700 ] && [ "$(m $I/home/admin/.ssh/authorized_keys)" = 600 ]; }
item6() {
  local f ok=1 admin=0
  for f in $I/etc/sudoers $I/etc/sudoers.d/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in *.*|*~) continue ;; esac
    visudo -cf "$f" >/dev/null 2>&1 || return 1
    grep -vE '^[[:space:]]*#' "$f" | grep -qE 'NOPASSWD:[[:space:]]*ALL([[:space:]]*(,|$))' && return 1
    grep -vE '^[[:space:]]*#' "$f" | grep -qE '^%?admin[[:space:]]+ALL[[:space:]]*=[[:space:]]*(\([^)]*\))?[[:space:]]*ALL[[:space:]]*$' && admin=1
  done
  [ $admin = 1 ]
}
item7() {
  local mask
  mask=$(cd "$SANDBOX" && env -i HOME=/tmp PATH=/usr/bin:/bin bash -c 'for f in image/etc/profile.d/*.sh; do [ -r "$f" ] && . "$f"; done; umask' 2>/dev/null)
  [ -n "$mask" ] && [ $((8#$mask & 8#027)) -eq $((8#027)) ]
}
item8() { [ "$(m $I/tmp)" = 1777 ] && [ "$(m $I/var/tmp)" = 1777 ]; }
item9() {
  local got
  got=$(find $I -type f -perm /6000 -printf '%P\n' | LC_ALL=C sort)
  [ "$got" = "$(LC_ALL=C sort $I/etc/suid-baseline.txt)" ] || return 1
  [ -u $I/usr/bin/sudo ] && [ -u $I/usr/bin/passwd ] && [ -u $I/usr/bin/mount ] && [ -g $I/usr/bin/wall ]
}
item10() {
  [ -f $I/etc/bash.bashrc ] || return 1
  local t a b hf
  t=$(mktemp -d "${TMPDIR:-/tmp}/lm-h24.XXXXXX") || return 1
  a="seen-$RANDOM"; b="hidden-$RANDOM"
  printf '%s\n' "echo $a" " echo $b" 'echo "@@HF=$HISTFILE@@"' > "$t/cmds"
  HOME="$t" HISTFILE="$t/.bash_history" timeout 10 bash --rcfile "$SANDBOX/$I/etc/bash.bashrc" -i < "$t/cmds" > "$t/out" 2>/dev/null
  hf=$(sed -n 's/.*@@HF=\(.*\)@@.*/\1/p' "$t/out" | tail -1)
  local r=1
  case "$hf" in "$t"/*) [ -f "$hf" ] && grep -qx "echo $a" "$hf" && ! grep -q "$b" "$hf" && r=0 ;; esac
  rm -rf "$t"; return $r
}
item11() {
  [ -f $I/etc/app/app.env ] && grep -q '^APP_ENV=production' $I/etc/app/app.env && [ -f $I/home/admin/.env ] || return 1
  if grep -rIiE '(password|secret|token|api_key)[a-z_]*[[:space:]]*=[[:space:]]*[^<$[:space:]]' $I --exclude='ssh_host_*' >/dev/null 2>&1; then return 1; fi
  if grep -rIE 'AKIA[0-9A-Z]{16}' $I >/dev/null 2>&1; then return 1; fi
  return 0
}
item12() {
  [ -z "$(find $I -type f -perm -0002 | head -1)" ] && [ -f $I/etc/cron.d/backup ] && [ -f $I/opt/app/run.sh ]
}

for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if ! item$n; then
    echo "❌ checklist item $n is not satisfied (the items after it have not been looked at)"; exit 1
  fi
done
echo "✅ all 12 checklist points are satisfied: the bastion image can go live"
exit 0
