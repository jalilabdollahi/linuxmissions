#!/bin/bash
# Source the sandbox etc/profile with an empty environment, under sh (dash on Ubuntu)
# and under bash --login: it must print nothing, and http_proxy, https_proxy and
# JAVA_HOME must be exported with the ticket's values; no_proxy must still hold the
# existing internal entries. etc/profile and the existing snippets stay as they were.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/profile etc/profile.d/01-no-proxy.sh etc/profile.d/02-editor.sh it-notes.txt 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/profile, one of the existing snippets or it-notes.txt was changed; add a new file in etc/profile.d instead (type 'reset' to get the originals back)"
  exit 1
fi

NEW=$(cd etc/profile.d && ls -A | grep -vxF -e 01-no-proxy.sh -e 02-editor.sh)
if [ -z "$NEW" ]; then
  echo "❌ there is no new file in etc/profile.d yet"
  exit 1
fi

T=$(mktemp -d "${TMPDIR:-/tmp}/lm-profile.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT
run() {  # run SHELL... -c SCRIPT : clean environment, sandbox etc
  env -i HOME="$T" PATH="/usr/bin:/bin" LM_ETC="$SANDBOX/etc" "$@"
}
WANT_PROXY=http://proxy.corp.example:3128
WANT_JAVA=/usr/lib/jvm/java-17-openjdk-amd64

check() {  # check LABEL SHELL-COMMAND...
  label=$1; shift
  out=$(run "$@" -c '. "$LM_ETC/profile"' 2>&1 < /dev/null)
  if [ -n "$out" ]; then
    first=$(printf '%s\n' "$out" | head -n 1)
    echo "❌ sourcing etc/profile under $label prints output (that breaks scp and sftp, and a syntax error here usually means a bash-only construct): $first"
    exit 1
  fi
  for v in http_proxy https_proxy JAVA_HOME; do
    case $v in JAVA_HOME) want=$WANT_JAVA ;; *) want=$WANT_PROXY ;; esac
    got=$(run "$@" -c '. "$LM_ETC/profile" >/dev/null 2>&1; printenv '"$v" 2>/dev/null < /dev/null)
    if [ "$got" != "$want" ]; then
      set_local=$(run "$@" -c '. "$LM_ETC/profile" >/dev/null 2>&1; eval "printf %s \"\${'"$v"'-UNSET}\""' 2>/dev/null < /dev/null)
      if [ -z "$got" ] && [ "$set_local" = UNSET ]; then
        if [ -n "$(printf '%s\n' "$NEW" | grep -v '\.sh$')" ]; then
          echo "❌ under $label $v is not set: a file in etc/profile.d that does not end in .sh is never sourced by etc/profile"
        else
          echo "❌ under $label $v is not set after sourcing etc/profile"
        fi
      elif [ -z "$got" ]; then
        echo "❌ under $label $v is set but not exported, so programs started from the shell do not see it"
      else
        echo "❌ under $label $v is '$got', expected '$want'"
      fi
      exit 1
    fi
  done
  np=$(run "$@" -c '. "$LM_ETC/profile" >/dev/null 2>&1; printenv no_proxy' 2>/dev/null < /dev/null)
  for e in localhost 127.0.0.1 .corp.example 10.0.0.0/8; do
    case ",$np," in
      *",$e,"*) ;;
      *) echo "❌ under $label no_proxy no longer contains $e: the existing internal exclusions must keep working"; exit 1 ;;
    esac
  done
}

check "sh" sh
check "bash -l" bash --login --noprofile
echo "✅ a clean login under sh and bash gets http_proxy, https_proxy and JAVA_HOME exported, silently, with no_proxy intact"
exit 0
