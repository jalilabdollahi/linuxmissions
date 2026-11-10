#!/bin/bash
# Ask ssh itself (ssh -G prints the effective options without connecting) for every host in
# the matrix plus bastion, github, gitlab and a stranger, with HOME pointing at the sandbox.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s home/.ssh/config ]; then
  echo "❌ home/.ssh/config is missing or empty"
  exit 1
fi
if cmp -s home/.ssh/config .lm-state/config.orig; then
  echo "❌ home/.ssh/config has not been changed yet"
  exit 1
fi

export HOME="$SANDBOX/home"
G() { ssh -G -F "$HOME/.ssh/config" "$1" 2>&1; }
opt() { printf '%s\n' "$1" | awk -v k="$2" '$1 == k { sub(/^[^ ]+ /, ""); print; exit }'; }
me=$(id -un)

if ! G db-1 | grep -q '^hostname '; then
  echo "❌ ssh cannot read the config: $(G db-1 | head -1)"
  exit 1
fi

check() {  # host user port key-relative-path hostname proxyjump(or none)
  local out; out=$(G "$1")
  local u p k hn pj
  u=$(opt "$out" user); p=$(opt "$out" port); k=$(opt "$out" identityfile); hn=$(opt "$out" hostname)
  pj=$(opt "$out" proxyjump)
  k=${k/#\~/$HOME}      # ssh -G prints a leading ~ unexpanded
  [ -n "$pj" ] || pj=none
  case "$pj" in bastion.corp|jump@bastion.corp) [ "$6" = bastion ] && pj=bastion ;; esac
  if [ "$u" != "$2" ]; then echo "❌ ssh $1 would log in as '$u', expected '$2'"; exit 1; fi
  if [ "$p" != "$3" ]; then echo "❌ ssh $1 would use port $p, expected $3"; exit 1; fi
  if [ "$k" != "$HOME/.ssh/$4" ]; then echo "❌ ssh $1 would try key '${k/#$HOME/~}' first, expected ~/.ssh/$4"; exit 1; fi
  if [ "$hn" != "$5" ]; then echo "❌ ssh $1 would connect to '$hn', expected '$5'"; exit 1; fi
  if [ "$pj" != "$6" ]; then echo "❌ ssh $1 has ProxyJump '$pj', expected '$6'"; exit 1; fi
  if [ "$(opt "$out" serveraliveinterval)" != 30 ]; then echo "❌ ssh $1: ServerAliveInterval is not 30"; exit 1; fi
  if [ "$(opt "$out" forwardagent)" != no ]; then echo "❌ ssh $1: agent forwarding is on"; exit 1; fi
}

while read -r host user port key; do
  check "$host" "$user" "$port" "$key" "$host.corp.internal" bastion
  if [ "$(opt "$(G "$host")" identitiesonly)" != yes ]; then
    echo "❌ ssh $host: without IdentitiesOnly ssh also offers the agent's other keys (too many auth attempts)"
    exit 1
  fi
done < db-hosts.txt
check bastion.corp jump 22 keys/bastion bastion.corp none
check github.com git 22 keys/github github.com none
check gitlab.corp git 22 keys/gitlab gitlab.corp none

out=$(G stranger.example.org)
if [ "$(opt "$out" user)" != "$me" ]; then
  echo "❌ an unrelated host would get user '$(opt "$out" user)': the defaults must not force a User"
  exit 1
fi
if [ "$(opt "$out" proxyjump)" != "" ] || [ "$(opt "$out" forwardagent)" != no ] || [ "$(opt "$out" serveraliveinterval)" != 30 ]; then
  echo "❌ an unrelated host does not get exactly the safe defaults (no jump host, no agent forwarding, keepalive 30)"
  exit 1
fi
echo "✅ ssh -G agrees for all six db hosts, the bastion, github, gitlab and an unrelated host"
exit 0
