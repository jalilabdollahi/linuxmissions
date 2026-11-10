#!/bin/bash
# run.log must come from a real launcher.sh run that saw the ticket's values in
# its environment. The signature is recomputed from the per-setup id.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ "$(cksum < launcher.sh 2>/dev/null)" != "1583628058 782" ]; then
  echo "❌ launcher.sh was changed; the fix belongs in how you start it (type reset to restore it)"
  exit 1
fi
if [ ! -s .launcher-id ] || [ ! -f TICKET.txt ]; then
  echo "❌ a level file is missing; type reset to start over"
  exit 1
fi

region="$(sed -n 's/^ *APP_REGION: *//p' TICKET.txt | head -1)"
line="$(head -1 run.log 2>/dev/null | tr -d '\r')"
if [ -z "$line" ]; then
  echo "❌ run.log is empty or missing; start the worker with ./launcher.sh"
  exit 1
fi

set -- $line
mode="${2#mode=}"; got_region="${3#region=}"; sig="${4#sig=}"
want_sig="$(printf '%s|%s|%s' "$(cat .launcher-id)" "$mode" "$got_region" | cksum | cut -d' ' -f1)"

if [ "$1" != started ] || [ "$sig" != "$want_sig" ]; then
  echo "❌ run.log was not written by launcher.sh (its signature doesn't match); run the launcher instead of editing the log"
  exit 1
fi
if [ "$mode" = dev ] && [ "$got_region" = local ]; then
  echo "❌ the last start used the defaults (dev, local): launcher.sh did not see APP_MODE or APP_REGION in its environment"
  exit 1
fi
if [ "$mode" != prod ]; then
  echo "❌ the last start ran in '$mode' mode, the ticket wants prod"
  exit 1
fi
if [ "$got_region" != "$region" ]; then
  if [ "$got_region" = local ]; then
    echo "❌ the last start got APP_MODE but not APP_REGION; is the region exported too?"
  else
    echo "❌ the last start used region '$got_region', the ticket says $region"
  fi
  exit 1
fi

echo "✅ the worker started in prod mode for $region, and the launcher saw both variables"
exit 0
