#!/bin/bash
# Starts brand-new shells with HOME=home/ (a login shell and a terminal-tab
# shell) and asks each what `deploy` is, where it resolves to, and what it runs.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
S="$(pwd -P)"

for f in tools/bin/deploy opt/deploy-1.4/bin/deploy scripts/deploy-legacy.sh; do
  if [ ! -x "$f" ]; then
    echo "❌ $f is missing or not executable; the old versions stay on disk for rollbacks (type reset)"
    exit 1
  fi
done

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 10"
PROBE='echo "TYPE=$(type -t deploy)"; echo "CMD=$(command -v deploy)"; echo "RUN=$(deploy --version 2>&1 | head -1)";
echo "LL=$(type -t ll)"; echo "GS=$(type -t gs)"; echo "MKCD=$(type -t mkcd)"; echo "LS=$(command -v ls)"'

# probe KIND FLAGS
probe() {
  (cd "$S/home" && $LIMIT env -i HOME="$S/home" PATH=/usr/bin:/bin TERM=dumb USER=deployer \
     bash $2 -c "$PROBE" </dev/null 2>/dev/null)
}
get() { printf '%s\n' "$1" | grep "^$2=" | head -1 | cut -d= -f2-; }

for kind in login tab; do
  if [ "$kind" = login ]; then
    out="$(probe login '-l -i')"; name="a login shell (bash -l, like SSH)"
  else
    out="$(probe tab '-i')"; name="a new terminal tab (bash -i)"
  fi
  t="$(get "$out" TYPE)"; c="$(get "$out" CMD)"; r="$(get "$out" RUN)"
  case "$t" in
    alias)
      where="$(cd "$S/home" && grep -rls 'alias deploy' .bash_profile .bashrc .profile .config 2>/dev/null | head -1)"
      echo "❌ in $name, deploy is an alias${where:+ (defined in $where)}"; exit 1 ;;
    function)
      where="$(cd "$S/home" && grep -rlsE '(^|[[:space:]])deploy[[:space:]]*\(\)' .bash_profile .bashrc .profile .config 2>/dev/null | head -1)"
      echo "❌ in $name, deploy is a shell function${where:+ (defined in $where)}; a function wins over PATH"; exit 1 ;;
    file) ;;
    '')
      echo "❌ in $name, deploy is not found at all; is tools/bin on PATH there?"; exit 1 ;;
    *)
      echo "❌ in $name, deploy is a $t, not a program on PATH"; exit 1 ;;
  esac
  real="$(cd "$(dirname "$c")" 2>/dev/null && pwd -P)/$(basename "$c")"
  if [ "$real" != "$S/tools/bin/deploy" ]; then
    echo "❌ in $name, deploy resolves to $c; PATH finds another copy before tools/bin"
    exit 1
  fi
  if [ "$r" != "deploy 2.3.0 (tools/bin)" ]; then
    echo "❌ in $name, running deploy prints '$r' instead of the 2.3.0 banner"
    exit 1
  fi
  if [ -z "$(get "$out" LS)" ]; then
    echo "❌ in $name, ls is not found any more; PATH lost the system directories"
    exit 1
  fi
done

out="$(probe tab '-i')"
if [ "$(get "$out" LL)" != alias ] || [ "$(get "$out" GS)" != alias ] || [ "$(get "$out" MKCD)" != function ]; then
  echo "❌ in a new terminal tab the team shortcuts are broken (ll: $(get "$out" LL), gs: $(get "$out" GS), mkcd: $(get "$out" MKCD)); remove only the deploy definitions"
  exit 1
fi

echo "✅ login shells and terminal tabs both run tools/bin/deploy, and ll, gs and mkcd still work"
exit 0
