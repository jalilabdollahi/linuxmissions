#!/bin/bash
# Regenerate with the mock (as a restart would), then check: the resolv.conf symlink is
# intact, the package's resolved.conf is unchanged, and the generated files carry the
# new servers and domains in the right order, with nothing left of the old server.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -L etc/resolv.conf ]; then
  echo "❌ etc/resolv.conf is no longer a symlink: it was replaced by a regular file"
  exit 1
fi
if [ "$(readlink etc/resolv.conf)" != "../run/systemd/resolve/stub-resolv.conf" ]; then
  echo "❌ etc/resolv.conf points to $(readlink etc/resolv.conf), not to the stub file"
  exit 1
fi
if ! cmp -s etc/systemd/resolved.conf .lm-state/resolved.conf.orig; then
  echo "❌ etc/systemd/resolved.conf belongs to the package: put the change in a drop-in"
  exit 1
fi
if ! ls etc/systemd/resolved.conf.d/*.conf >/dev/null 2>&1; then
  echo "❌ there is no drop-in in etc/systemd/resolved.conf.d/"
  exit 1
fi

# What does the running resolver say now (the state the player created by restarting)?
live_servers=$(sed -n 's/^nameserver //p' run/systemd/resolve/resolv.conf | tr '\n' ' ')
live_search=$(sed -n 's/^search //p' run/systemd/resolve/resolv.conf)
if [ "$live_servers" = "10.20.0.53 10.20.0.54 " ] && [ "$live_search" = "corp.example lab.example" ]; then
  restarted=1
else
  restarted=0
fi

# The configuration itself: what a restart would produce from the files as they are now.
bin/systemctl restart systemd-resolved 2>/dev/null
servers=$(sed -n 's/^nameserver //p' run/systemd/resolve/resolv.conf | tr '\n' ' ')
search=$(sed -n 's/^search //p' run/systemd/resolve/resolv.conf)
stubsearch=$(sed -n 's/^search //p' run/systemd/resolve/stub-resolv.conf)

if [ "$servers" != "10.20.0.53 10.20.0.54 " ]; then
  echo "❌ systemd-resolved would use DNS servers '${servers% }', expected exactly 10.20.0.53 10.20.0.54 in that order"
  exit 1
fi
if [ "$search" != "corp.example lab.example" ] || [ "$stubsearch" != "corp.example lab.example" ]; then
  echo "❌ the search domains would be '$search', expected corp.example lab.example in that order"
  exit 1
fi
if [ "$restarted" != 1 ]; then
  echo "❌ the configuration is right, but the running resolver has not picked it up yet: restart systemd-resolved"
  exit 1
fi
echo "✅ resolved is configured through a drop-in, restarted, and etc/resolv.conf is still the stub symlink"
exit 0
