#!/bin/bash
# ./login-sim must print the agreed PATH for both deploy and ops: the system directories,
# then /opt/<app>/bin, with no empty components and no duplicates; /etc/environment must
# hold a literal, valid PATH.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
cksum bin/login-sim sysroot/etc/profile 2>/dev/null | cmp -s - .lm-state/sums || { echo "❌ login-sim or sysroot/etc/profile was changed; type 'reset' to get them back"; exit 1; }
WANT=$(cat .lm-state/want)
APP=$(cat .lm-state/app)
check() {  # check USER
  local got=$(bin/login-sim "$1" 2>/dev/null)
  got=${got#PATH=}
  [ "$got" = "$WANT" ] && return 0
  case "$got" in
    *'$'*) echo "❌ the PATH of $1 contains a literal \$PATH: some file that is not a shell script is read literally"; return 1 ;;
  esac
  case ":$got:" in
    *::*) echo "❌ the PATH of $1 has an empty component (a stray colon): it means the current directory"; return 1 ;;
  esac
  local dups=$(printf '%s' "$got" | tr ':' '\n' | sort | uniq -d | head -n1)
  [ -n "$dups" ] && { echo "❌ the PATH of $1 lists $dups more than once"; return 1; }
  case ":$got:" in
    *:/opt/$APP/bin:*) ;;
    *) echo "❌ the PATH of $1 does not contain the application directory"; return 1 ;;
  esac
  case "$got" in
    /opt/*|"$HOME"*) echo "❌ the PATH of $1 starts with a directory that should come after the system ones"; return 1 ;;
  esac
  echo "❌ the PATH of $1 is not the agreed one (system directories, then the application directory only)"; return 1
}
check deploy || exit 1
check ops || exit 1
E=$(grep -E '^PATH=' sysroot/etc/environment | tail -n1 | sed -e 's/^PATH=//' -e 's/^"//' -e 's/"$//')
case "$E" in
  ''|*'$'*|*::*|:*|*:) echo "❌ the PATH line in /etc/environment is empty or not a literal list of directories"; exit 1 ;;
esac
echo "✅ both logins get the agreed PATH: $WANT"
