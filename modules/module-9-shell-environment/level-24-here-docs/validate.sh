#!/bin/bash
# Runs bootstrap.sh twice for a fresh newcomer (HOME = a copy of the skeleton,
# random TEAM/OWNER, a PATH that only exists at bootstrap time), then logs in
# as that newcomer with a different PATH and USER, in a login shell and in an
# interactive non-login shell, and checks what each shell ends up with.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
S="$(pwd -P)"

if [ ! -f bootstrap.sh ]; then
  echo "❌ bootstrap.sh is missing (type reset)"
  exit 1
fi
if [ ! -x tools/bin/teamctl ]; then
  echo "❌ tools/bin/teamctl is missing (type reset)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
T="$WORK/newcomer"
mkdir -p "$T" "$WORK/boot-only/bin" "$WORK/login-only/bin"
cat > "$T/.bashrc" <<'EOF'
# ~/.bashrc: executed by bash for non-login shells.
case $- in
    *i*) ;;
      *) return;;
esac
HISTSIZE=1000
alias ll='ls -alF'
EOF
printf '# ~/.profile\n' > "$T/.profile"

teams=(payments search identity growth platform)
first=(Ana Bruno Chen Dara Emil Farah)
last=(Lima Novak Okafor Silva Tanaka)
TEAM_V="${teams[$(( RANDOM % 5 ))]}-$(( RANDOM % 90 + 10 ))"
OWNER_V="${first[$(( RANDOM % 6 ))]} ${last[$(( RANDOM % 5 ))]}"
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"

boot() {
  (cd "$WORK" && $LIMIT env -i HOME="$T" PATH="/usr/bin:/bin:$WORK/boot-only/bin" USER=bootstrapper \
     TEAM="$TEAM_V" OWNER="$OWNER_V" bash "$S/bootstrap.sh" </dev/null >"$WORK/boot.out" 2>&1)
}
save() {  # save DIR: copy the three startup files (or a marker if missing)
  mkdir -p "$1"
  for f in .bashrc .bash_profile team.env; do
    src="$T/$f"; [ "$f" = team.env ] && src="$T/.config/team.env"
    if [ -f "$src" ]; then cp "$src" "$1/$f"; else echo "(missing)" > "$1/$f"; fi
  done
}

if ! boot; then
  echo "❌ bootstrap.sh failed: $(tail -1 "$WORK/boot.out")"
  exit 1
fi
save "$WORK/run1"

# team.env: fixed values, safe to source.
if [ ! -f "$T/.config/team.env" ]; then
  echo "❌ bootstrap.sh did not create ~/.config/team.env"
  exit 1
fi
got="$(env -i bash --noprofile --norc -c 'source "$1/.config/team.env" 2>/dev/null; printf "%s|%s" "$TEAM" "$OWNER"' _ "$T")"
if [ "$got" != "$TEAM_V|$OWNER_V" ]; then
  if grep -q '\$' "$T/.config/team.env"; then
    echo "❌ team.env still contains \$ variables; TEAM and OWNER must be written as fixed values when bootstrap runs"
  else
    echo "❌ sourcing team.env gives TEAM='${got%%|*}' OWNER='${got#*|}', expected TEAM='$TEAM_V' OWNER='$OWNER_V' (an OWNER with a space needs quotes)"
  fi
  exit 1
fi

# The newcomer's own .bashrc must survive.
if ! grep -qx "alias ll='ls -alF'" "$T/.bashrc" || ! grep -qx 'HISTSIZE=1000' "$T/.bashrc"; then
  echo "❌ bootstrap.sh replaced the existing ~/.bashrc; add the team setup to it, keep what was there"
  exit 1
fi

# Second run: nothing may change.
if ! boot; then
  echo "❌ bootstrap.sh failed when run a second time: $(tail -1 "$WORK/boot.out")"
  exit 1
fi
save "$WORK/run2"
for f in .bashrc .bash_profile team.env; do
  if ! cmp -s "$WORK/run1/$f" "$WORK/run2/$f"; then
    [ "$f" = team.env ] && f=.config/team.env
    echo "❌ running bootstrap.sh a second time changed ~/$f (a block added again?); a rerun must change nothing"
    exit 1
  fi
done

# Log in as the newcomer: a login shell and a terminal-tab shell.
PROBE='echo "PATH=$PATH"; echo "TEAM=$(printenv TEAM)"; echo "OWNER=$(printenv OWNER)";
echo "TC=$(command -v teamctl)"; echo "LL=$(type -t ll)"; echo "MINE=$(type -t mine)"; echo "RUN=$(mine 2>&1)"'
for flags in "-l -i" "-i"; do
  if [ "$flags" = "-i" ]; then name="a non-login shell (bash -i)"; else name="a login shell (bash -l)"; fi
  out="$(cd "$T" && $LIMIT env -i HOME="$T" PATH="/usr/bin:/bin:$WORK/login-only/bin" USER=newbie TERM=dumb \
          bash $flags -c "$PROBE" </dev/null 2>/dev/null)"
  get() { printf '%s\n' "$out" | grep "^$1=" | head -1 | cut -d= -f2-; }
  p="$(get PATH)"
  firstdir="${p%%:*}"
  realfirst="$(cd "$firstdir" 2>/dev/null && pwd -P)"
  case ":$p:" in
    *"/boot-only/"*)
      echo "❌ in $name, PATH still contains the PATH from bootstrap time; \$PATH must be expanded at login, not when bootstrap runs"; exit 1 ;;
  esac
  case ":$p:" in
    *":$WORK/login-only/bin:"*) ;;
    *) echo "❌ in $name, PATH lost the directories the shell started with"; exit 1 ;;
  esac
  if [ "$realfirst" != "$S/tools/bin" ]; then
    if [ -z "$(get MINE)" ] && [ "$flags" = "-l -i" ]; then
      echo "❌ in $name, nothing from the team setup is there; does ~/.bash_profile read ~/.bashrc?"
    else
      echo "❌ in $name, the team tools ($S/tools/bin) are not first on PATH (first is '$firstdir')"
    fi
    exit 1
  fi
  n="$(printf '%s\n' "$p" | tr ':' '\n' | while read -r d; do (cd "$d" 2>/dev/null && pwd -P); done | grep -cx "$S/tools/bin")"
  if [ "$n" -ne 1 ]; then
    echo "❌ in $name, the tools directory is on PATH $n times"
    exit 1
  fi
  if [ "$(get TEAM)" != "$TEAM_V" ] || [ "$(get OWNER)" != "$OWNER_V" ]; then
    echo "❌ in $name, TEAM/OWNER are not exported with the bootstrap values (got TEAM='$(get TEAM)' OWNER='$(get OWNER)')"
    exit 1
  fi
  if [ "$(get MINE)" != alias ]; then
    echo "❌ in $name, there is no alias 'mine'"
    exit 1
  fi
  if [ "$(get RUN)" != "teamctl: open tasks for owner 'newbie' in team $TEAM_V" ]; then
    echo "❌ in $name, 'mine' printed: $(get RUN) (the user must be the one logged in, not the one who ran bootstrap)"
    exit 1
  fi
  if [ "$(get LL)" != alias ]; then
    echo "❌ in $name, the newcomer's own alias ll is gone"
    exit 1
  fi
done

echo "✅ bootstrap.sh sets fixed TEAM/OWNER, a login-time PATH and alias, keeps .bashrc, and is safe to rerun"
exit 0
