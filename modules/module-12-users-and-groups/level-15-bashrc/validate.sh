#!/bin/bash
# Non-interactive: bash -c '. ~/.bashrc; echo OK' prints exactly OK.
# Interactive: bash -i still prints the banner once and sets the aliases,
# PATH and EDITOR. The lines of the original setup must still be there.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
RC=home/kim/.bashrc

if [ ! -s .lm-state/want ] || [ ! -x bin/zsh ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
. .lm-state/want
if [ ! -f "$RC" ]; then
  echo "❌ home/kim/.bashrc does not exist any more"
  exit 1
fi
H="$SANDBOX/home/kim"

for needle in "alias ll='ls -alF'" "alias gs='git status -sb'" "alias k='kubectl'" "export EDITOR=vim" "exec zsh" "=== $HOST | Kim Nowak | maintenance window $WIN ==="; do
  if ! grep -qF -- "$needle" "$RC"; then
    echo "❌ a line of Kim's setup is gone from .bashrc ($needle); the fix is to guard it, not to delete it"
    exit 1
  fi
done

out=$(env -i HOME="$H" PATH="$SANDBOX/bin:/usr/bin:/bin" /bin/bash -c '. ~/.bashrc; echo OK' </dev/null 2>&1)
rc=$?
if [ "$out" != OK ]; then
  case "$out" in
    "") echo "❌ the non-interactive shell ended before 'echo OK' ran (exit $rc): a sourced file that ends the shell with exit or exec kills scp's session too" ;;
    *OK) echo "❌ the non-interactive shell still prints extra output before OK: $(printf '%s' "${out%OK}" | head -n 1 | cut -c1-60)" ;;
    *)   echo "❌ the non-interactive shell prints '$(printf '%s' "$out" | head -n 1 | cut -c1-60)' instead of just OK" ;;
  esac
  exit 1
fi

# interactive run: a stand-in exec lets the file's "exec zsh" through without replacing this test shell
printf 'exec() { :; }\n. "$HOME/.bashrc"\n' > .lm-state/iwrap.rc
iout=$(printf 'alias ll gs k\necho "PATH=$PATH"\necho "EDITOR=$EDITOR"\n' | env -i HOME="$H" PATH=/usr/bin:/bin TERM=dumb /bin/bash --rcfile "$SANDBOX/.lm-state/iwrap.rc" -i 2>/dev/null)
n=$(printf '%s\n' "$iout" | grep -cxF "=== $HOST | Kim Nowak | maintenance window $WIN ===")
if [ "$n" = 0 ]; then
  echo "❌ an interactive shell no longer prints Kim's banner"
  exit 1
fi
if [ "$n" != 1 ]; then
  echo "❌ an interactive shell prints the banner $n times"
  exit 1
fi
for a in "alias ll='ls -alF'" "alias gs='git status -sb'" "alias k='kubectl'"; do
  if ! printf '%s\n' "$iout" | grep -qxF -- "$a"; then
    echo "❌ an interactive shell is missing Kim's ${a%%=*}"
    exit 1
  fi
done
if ! printf '%s\n' "$iout" | grep -q "^PATH=$H/bin:"; then
  echo "❌ an interactive shell lost the \$HOME/bin entry at the front of PATH"
  exit 1
fi
if ! printf '%s\n' "$iout" | grep -qxF "EDITOR=vim"; then
  echo "❌ an interactive shell lost EDITOR=vim"
  exit 1
fi
echo "✅ scp-safe: non-interactive shells print just OK, interactive ones keep the banner, aliases, PATH and EDITOR"
exit 0
