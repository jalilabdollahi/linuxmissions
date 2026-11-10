#!/bin/bash
# Starts a clean login shell and a clean interactive non-login shell with
# HOME=home/ and checks what each one ends up with.
SANDBOX="$1"
H="$SANDBOX/home"
WANT=/srv/projects/billing-api

if [ ! -d "$H" ]; then
  echo "❌ the home/ directory is missing (type reset to start over)"
  exit 1
fi

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"
probe='printf "root=%s\n" "$(printenv PROJECT_ROOT)"; printf "editor=%s\n" "$EDITOR"; printf "path=%s\n" "$PATH"; alias ll >/dev/null 2>&1 && echo alias=yes'

login="$(cd / && $LIMIT env -i HOME="$H" PATH=/usr/bin:/bin TERM=dumb bash -l -c "$probe" </dev/null 2>/dev/null)"
inter="$(cd / && $LIMIT env -i HOME="$H" PATH=/usr/bin:/bin TERM=dumb bash -i -c "$probe" </dev/null 2>/dev/null)"

field() { printf '%s\n' "$1" | sed -n "s/^$2=//p" | tail -1; }

lroot="$(field "$login" root)"
iroot="$(field "$inter" root)"

if [ -z "$lroot" ] && [ -z "$iroot" ]; then
  echo "❌ neither a login shell (bash -l) nor a new terminal tab (bash -i) gets PROJECT_ROOT yet"
  exit 1
fi
if [ -z "$lroot" ]; then
  echo "❌ a login shell (bash -l, like an SSH login) has no exported PROJECT_ROOT; which file does it read?"
  exit 1
fi
if [ -z "$iroot" ]; then
  echo "❌ an interactive non-login shell (bash -i, a new terminal tab) has no exported PROJECT_ROOT; it reads only ~/.bashrc"
  exit 1
fi
if [ "$lroot" != "$WANT" ] || [ "$iroot" != "$WANT" ]; then
  echo "❌ PROJECT_ROOT is '$lroot' in login shells and '$iroot' in terminal tabs, expected $WANT"
  exit 1
fi

if [ "$(field "$login" editor)" != vim ] || ! field "$login" path | tr ':' '\n' | grep -qxF "$H/bin"; then
  echo "❌ login shells lost the old .bash_profile settings (EDITOR=vim and ~/bin at the front of PATH)"
  exit 1
fi
if [ "$(field "$inter" alias)" != yes ]; then
  echo "❌ the aliases from .bashrc (ll, gs) are gone in interactive shells"
  exit 1
fi

count=$(cat "$H/.bash_profile" "$H/.profile" "$H/.bashrc" 2>/dev/null \
  | grep -cE '^[[:space:]]*(export[[:space:]]+|declare[[:space:]]+-x[[:space:]]+)?PROJECT_ROOT=')
if [ "$count" -ne 1 ]; then
  echo "❌ PROJECT_ROOT is assigned $count times across .bash_profile, .profile and .bashrc; keep exactly one definition and load it from the other file"
  exit 1
fi

echo "✅ login shells and new terminal tabs both get PROJECT_ROOT=$WANT from one definition"
exit 0
