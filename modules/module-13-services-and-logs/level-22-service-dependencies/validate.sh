#!/bin/bash
# Simulated boot (systemctl mock-boot): no ordering cycle, db-proxy started
# before app, nothing failed, all three services up. Then: stopping db-proxy
# stops app; stopping app leaves db-proxy running (the dependency points one
# way). The programs under /opt are unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC=bin/systemctl

if [ ! -s .lm-state/sha ] || [ ! -f etc/systemd/system/app.service ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
if ! sha256sum -c --quiet .lm-state/sha >/dev/null 2>&1; then
  echo "❌ one of the programs under /opt was modified; the fix belongs in the unit files"
  exit 1
fi
for u in app db-proxy cache; do
  if [ "$($SC is-enabled $u.service 2>/dev/null)" != enabled ]; then
    echo "❌ $u.service is no longer enabled"
    exit 1
  fi
done
if $SC status app.service db-proxy.service 2>&1 | grep -q 'changed on disk'; then
  echo "❌ a unit changed on disk and systemd still has the old definition (daemon-reload)"
  exit 1
fi

out=$($SC mock-boot 2>&1); rc=$?
if echo "$out" | grep -qi 'ordering cycle'; then
  echo "❌ systemd found an ordering cycle during boot ($(echo "$out" | grep -i 'ordering cycle' | head -1)); some unit orders itself after something that is ordered after it"
  exit 1
fi
db=$(echo "$out" | grep -n 'Started db-proxy.service' | head -1 | cut -d: -f1)
ap=$(echo "$out" | grep -n 'Started app.service' | head -1 | cut -d: -f1)
if [ -z "$db" ]; then
  echo "❌ db-proxy.service was not started at boot"
  exit 1
fi
if [ -z "$ap" ]; then
  echo "❌ app.service was not started at boot"
  exit 1
fi
if [ "$ap" -lt "$db" ]; then
  echo "❌ at boot app.service is still started before db-proxy.service: nothing orders them (a dependency alone only says 'start it too', not 'start it first')"
  exit 1
fi
if [ "$rc" != 0 ]; then
  echo "❌ the simulated boot reports a failure: $(echo "$out" | grep -E 'FAILED|DEPEND' | head -1)"
  exit 1
fi
for u in app db-proxy cache; do
  if [ "$($SC is-active $u.service)" != active ]; then
    echo "❌ after the simulated boot $u.service is $($SC is-active $u.service)"
    exit 1
  fi
done

# Stopping db-proxy must take app down.
$SC stop db-proxy.service >/dev/null 2>&1
if [ "$($SC is-active app.service)" = active ]; then
  echo "❌ db-proxy.service was stopped but app.service keeps running; app has to go down with db-proxy"
  exit 1
fi
# ...and not the other way round.
$SC start app.service >/dev/null 2>&1
if [ "$($SC is-active db-proxy.service)" != active ] || [ "$($SC is-active app.service)" != active ]; then
  echo "❌ starting app.service does not bring db-proxy.service up with it"
  exit 1
fi
$SC stop app.service >/dev/null 2>&1
if [ "$($SC is-active db-proxy.service)" != active ]; then
  echo "❌ stopping app.service also stopped db-proxy.service; the dependency points the wrong way (db-proxy must not depend on app)"
  exit 1
fi
$SC start app.service >/dev/null 2>&1

echo "✅ boot order fixed: db-proxy starts before app, no ordering cycle, app follows db-proxy down, db-proxy outlives app"
exit 0
