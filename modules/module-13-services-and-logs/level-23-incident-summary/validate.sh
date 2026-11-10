#!/bin/bash
# incident.txt has the four exact fields (first_error_utc, root_cause_unit,
# trigger, failed_requests), and the fix holds: the causing unit runs again
# without debug logging (restarted, env file fixed, debug.log gone or tiny),
# the postgres WAL archive is still there, api, nginx and postgresql run.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
SC=bin/systemctl

if [ ! -s .lm-state/truth ]; then
  echo "❌ the level's data is gone; type 'reset'"
  exit 1
fi
. .lm-state/truth
if ! sha256sum -c --quiet .lm-state/sources.sum >/dev/null 2>&1; then
  echo "❌ one of the evidence files (journal export, access.log, dmesg.txt, df-snapshot.txt) was changed or removed; type 'reset'"
  exit 1
fi
if [ ! -f incident.txt ]; then
  echo "❌ incident.txt does not exist"
  exit 1
fi

get() { grep -E "^$1=" incident.txt | tail -1 | cut -d= -f2- | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
first=$(get first_error_utc); cause=$(get root_cause_unit); trig=$(get trigger); n=$(get failed_requests)

# --- the report -------------------------------------------------------------
if [ -z "$first" ]; then echo "❌ first_error_utc= is empty in incident.txt"; exit 1; fi
if ! echo "$first" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
  echo "❌ first_error_utc must look like 2026-11-10T02:04:41Z (UTC, seconds, trailing Z)"
  exit 1
fi
if [ "$first" != "$FIRST" ]; then
  loc=$(python3 - "$FIRST" <<'PY'
import sys
from datetime import datetime, timedelta
t = datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%M:%SZ") + timedelta(hours=1)
print(t.strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)
  if [ "$first" = "$loc" ]; then
    echo "❌ first_error_utc has the right moment, but in local time (the server is on UTC+1); the field is UTC"
  else
    echo "❌ first_error_utc is not the earliest entry of priority err or worse in the journal export; look at every unit, not only the loudest, and convert to UTC"
  fi
  exit 1
fi

if [ -z "$cause" ]; then echo "❌ root_cause_unit= is empty in incident.txt"; exit 1; fi
if [ "$cause" != "$CAUSE.service" ]; then
  case $cause in
    api.service) echo "❌ root_cause_unit: api is the loudest unit, but is it the cause or a victim? What was it failing to do?" ;;
    postgresql.service|nginx.service) echo "❌ root_cause_unit: $cause reports trouble, but something else made that trouble; follow the disk" ;;
    *.service) echo "❌ root_cause_unit: $cause is not what filled the disk" ;;
    *) echo "❌ root_cause_unit must be a unit name with the .service suffix" ;;
  esac
  exit 1
fi

if [ -z "$trig" ]; then echo "❌ trigger= is empty in incident.txt"; exit 1; fi
case $trig in
  config-change|deploy|cron-job|traffic-spike|hardware-fault|certificate-expiry) ;;
  *) echo "❌ trigger '$trig' is not one of: config-change, deploy, cron-job, traffic-spike, hardware-fault, certificate-expiry"; exit 1 ;;
esac
if [ "$trig" != "$TRIGGER" ]; then
  echo "❌ trigger '$trig' does not match what the journal says happened to $CAUSE just before it started writing debug logs"
  exit 1
fi

if [ -z "$n" ]; then echo "❌ failed_requests= is empty in incident.txt"; exit 1; fi
case $n in *[!0-9]*) echo "❌ failed_requests must be a number"; exit 1 ;; esac
if [ "$n" != "$N502" ]; then
  total=$(awk '$9 == 502' var/log/nginx/access.log | wc -l | tr -d ' ')
  allg=$(grep -c ' 502 ' var/log/nginx/access.log)
  if [ "$n" = "$allg" ] && [ "$n" != "$total" ]; then
    echo "❌ failed_requests also counts lines that only contain 502 somewhere (a size, a path); count the status field"
  elif [ "$n" = "$total" ]; then
    echo "❌ failed_requests counts every 502 in access.log, including some from before the first error; the window starts at first_error_utc (the log is in local time)"
  elif [ "$n" -gt "$N502" ]; then
    echo "❌ failed_requests is too high: only status 502 counts, from first_error_utc to the end of the log"
  else
    echo "❌ failed_requests is too low: count every 502 from first_error_utc to the end of the log"
  fi
  exit 1
fi

# --- the fix ----------------------------------------------------------------
U=$CAUSE.service
D=var/log/$CAUSE/debug.log
if [ -e "$D" ] && [ "$(stat -c %s "$D")" -gt 104857600 ]; then
  echo "❌ the incident is written up, but $D is still $(( $(stat -c %s "$D") / 1048576 )) MiB: the disk damage is still there"
  exit 1
fi
if [ ! -e var/lib/postgresql/wal-archive.bak ]; then
  echo "❌ var/lib/postgresql/wal-archive.bak is gone: that is postgres' WAL archive, not part of the damage"
  exit 1
fi
if grep -qE '^LOG_LEVEL=debug' etc/$CAUSE/env; then
  echo "❌ etc/$CAUSE/env still sets LOG_LEVEL=debug: the cause would fill the disk again"
  exit 1
fi
if $SC status "$U" 2>&1 | grep -q 'changed on disk'; then
  echo "❌ $U changed on disk; systemd still has the old definition"
  exit 1
fi
pid=$($SC show -P MainPID "$U")
if [ "$($SC is-active "$U")" != active ] || [ "$pid" = 0 ] || [ ! -r /proc/$pid/environ ]; then
  echo "❌ $U is not running"
  exit 1
fi
if [ "$pid" = "$(cat .lm-state/cause.pid)" ]; then
  echo "❌ $U is still the process that started before the fix (PID $pid); the new setting only reaches it when it restarts"
  exit 1
fi
if tr '\0' '\n' < /proc/$pid/environ | grep -qx 'LOG_LEVEL=debug'; then
  echo "❌ $U runs again, but its process still has LOG_LEVEL=debug"
  exit 1
fi
for u in nginx postgresql; do
  if [ "$($SC is-active $u.service)" != active ]; then
    echo "❌ $u.service is not running; it was fine before and must stay that way"
    exit 1
  fi
done
if [ "$($SC is-active api.service)" != active ]; then
  res=$($SC show -P Result api.service)
  if [ "$res" = start-limit-hit ]; then
    echo "❌ the cause is fixed, but api.service is still failed (start-limit-hit): it has to be reset and started again"
  else
    echo "❌ the cause is fixed, but api.service is not running ($($SC is-active api.service))"
  fi
  exit 1
fi
sleep 1
if [ "$($SC is-active api.service)" != active ]; then
  echo "❌ api.service started but died again; is there still no room?"
  exit 1
fi
echo "✅ report matches ($FIRST, $cause, $trig, $n failed requests) and $CAUSE no longer fills the disk; api, nginx and postgresql are up"
exit 0
