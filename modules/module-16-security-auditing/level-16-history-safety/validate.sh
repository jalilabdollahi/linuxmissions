#!/bin/bash
# 1. home/.bash_history == original minus the five secret lines (order kept), still mode 600.
# 2. An interactive bash started with HOME=<tmp> using home/.bashrc must save normal commands
#    and drop commands typed with a leading space.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
[ -f home/.bash_history ] || { echo "❌ home/.bash_history is missing"; exit 1; }
if ! cmp -s home/.bash_history .lm-state/expected; then
  have=$(wc -l < home/.bash_history); want=$(wc -l < .lm-state/expected)
  if [ "$have" -gt "$want" ]; then echo "❌ home/.bash_history still has $((have - want)) line(s) that carry a secret"
  elif [ "$have" -lt "$want" ]; then echo "❌ home/.bash_history lost $((want - have)) harmless line(s) or more than it should"
  else echo "❌ home/.bash_history has the right number of lines but they are not the original harmless ones in order"; fi
  exit 1
fi
[ "$(stat -c %a home/.bash_history)" = 600 ] || { echo "❌ home/.bash_history should still be mode 600 (now $(stat -c %a home/.bash_history))"; exit 1; }
[ -f home/.bashrc ] || { echo "❌ home/.bashrc is missing"; exit 1; }
grep -q "^alias ll=" home/.bashrc && grep -q "^PS1=" home/.bashrc || { echo "❌ the rest of home/.bashrc (prompt, aliases) was removed"; exit 1; }

t=$(mktemp -d "${TMPDIR:-/tmp}/lm-hist.XXXXXX") || exit 1
trap 'rm -rf "$t"' EXIT
cp home/.bashrc "$t/.bashrc"
a="visible-$RANDOM"; b="hidden-$RANDOM"; c="visible-$RANDOM"
printf '%s\n' "echo $a" " echo $b" "echo $c" 'echo "@@HF=$HISTFILE@@"' > "$t/cmds"
HOME="$t" HISTFILE="$t/.bash_history" timeout 10 bash --rcfile "$t/.bashrc" -i < "$t/cmds" > "$t/out" 2>/dev/null
hf=$(sed -n 's/.*@@HF=\(.*\)@@.*/\1/p' "$t/out" | tail -1)
case "$hf" in "$t"/*) ;; *) echo "❌ the .bashrc sends the history to $hf instead of the user's own history file"; exit 1 ;; esac
[ -f "$hf" ] || { echo "❌ an interactive shell with this .bashrc saves no history at all"; exit 1; }
grep -qx "echo $a" "$hf" && grep -qx "echo $c" "$hf" || { echo "❌ with this .bashrc, ordinary commands are no longer saved to the history"; exit 1; }
grep -qx " echo $b" "$hf" && { echo "❌ a command typed with a leading space is still saved to the history"; exit 1; }
grep -q "$b" "$hf" && { echo "❌ a command typed with a leading space is still saved to the history"; exit 1; }
echo "✅ secrets are gone from the history and commands starting with a space will never be saved again"
exit 0
