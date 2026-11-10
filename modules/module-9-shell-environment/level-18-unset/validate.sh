#!/bin/bash
# Sources a pristine legacy-env.sh and then the player's reset-env.sh in a clean
# bash, and inspects that shell: variables unset (not just empty), cd is the
# builtin again, PATH/HOME untouched, no errors, the shell still alive.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f reset-env.sh ]; then
  echo "❌ reset-env.sh is missing"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp reset-env.sh "$WORK/reset-env.sh"
cat > "$WORK/legacy-env.sh" <<'EOF'
export http_proxy=http://proxy.legacy.corp:3128
export https_proxy=$http_proxy
export no_proxy=
export LD_LIBRARY_PATH=/opt/legacy/lib:/opt/oracle/instantclient_11_2
export GREP_OPTIONS='--color=always -i'
CDPATH=.:/opt/legacy/projects
readonly LEGACY_MODE=1
export LEGACY_MODE
cd() {
  builtin cd "$@" && echo "[legacy] now in $PWD"
}
EOF

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# probe WITH_LEGACY(0/1): run the scenario, stdout -> $WORK/out, stderr -> $WORK/err
probe() {
  (cd "$WORK" && $LIMIT env -i PATH="/usr/bin:/bin:$WORK/nowhere" HOME="$WORK/home" \
     bash --noprofile --norc -c '
    p0=$PATH; h0=$HOME
    [ "$1" = 1 ] && source ./legacy-env.sh
    source ./reset-env.sh
    echo "ALIVE"
    for v in http_proxy https_proxy no_proxy LD_LIBRARY_PATH GREP_OPTIONS CDPATH; do
      [ -n "${!v+x}" ] && echo "SET $v=${!v}"
    done
    echo "CD=$(type -t cd)"
    [ "$PATH" = "$p0" ] || echo "PATH_CHANGED"
    [ "$HOME" = "$h0" ] || echo "HOME_CHANGED"
  ' _ "$1" </dev/null >"$WORK/out" 2>"$WORK/err")
}

probe 1
if ! grep -qx ALIVE "$WORK/out"; then
  echo "❌ sourcing reset-env.sh ended the shell (exit, or set -e meeting an error); it must never close the caller's shell"
  exit 1
fi
if [ -s "$WORK/err" ]; then
  echo "❌ source reset-env.sh printed an error: $(head -1 "$WORK/err" | sed 's/^.*reset-env.sh: //')"
  exit 1
fi
set_line="$(grep '^SET ' "$WORK/out" | head -1)"
if [ -n "$set_line" ]; then
  name="${set_line#SET }"; val="${name#*=}"; name="${name%%=*}"
  if [ -z "$val" ]; then
    echo "❌ $name is still set (to an empty string); an empty variable is not an unset one"
  else
    echo "❌ $name is still set after source reset-env.sh"
  fi
  exit 1
fi
case "$(grep '^CD=' "$WORK/out")" in
  CD=builtin) ;;
  CD=function) echo "❌ cd is still the legacy function; remove the function so the builtin is used again"; exit 1 ;;
  *) echo "❌ cd is not the shell builtin after source reset-env.sh ($(grep '^CD=' "$WORK/out"))"; exit 1 ;;
esac
if grep -q PATH_CHANGED "$WORK/out"; then
  echo "❌ reset-env.sh changed PATH; legacy-env.sh never touched it, so leave it alone"
  exit 1
fi
if grep -q HOME_CHANGED "$WORK/out"; then
  echo "❌ reset-env.sh changed HOME; leave it alone"
  exit 1
fi

# It must also be harmless in a shell that never sourced legacy-env.sh.
probe 0
if ! grep -qx ALIVE "$WORK/out" || [ -s "$WORK/err" ] || [ "$(grep '^CD=' "$WORK/out")" != CD=builtin ] \
   || grep -q '_CHANGED' "$WORK/out"; then
  echo "❌ in a clean shell (legacy-env.sh not sourced), source reset-env.sh must do nothing harmful and print nothing"
  exit 1
fi

if [ ! -f readonly.txt ]; then
  echo "❌ readonly.txt does not exist yet: which name could reset-env.sh not remove?"
  exit 1
fi
if [ "$(tr -d ' \t\r' < readonly.txt | grep -v '^$')" != "LEGACY_MODE" ]; then
  echo "❌ readonly.txt should contain only the name of the variable that cannot be unset"
  exit 1
fi

echo "✅ reset-env.sh unsets the legacy variables and the cd function without errors; LEGACY_MODE stays (readonly)"
exit 0
