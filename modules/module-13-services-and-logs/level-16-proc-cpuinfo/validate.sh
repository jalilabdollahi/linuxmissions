#!/bin/bash
# etc/default/render-worker must hold exactly WORKERS=<physical cores> and
# BUILD=avx2|generic (comments allowed), both computed from capture/cpuinfo,
# and the running render-worker must have been started with those values.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
CONF=etc/default/render-worker
CPU=capture/cpuinfo

if [ ! -s "$CPU" ]; then
  echo "❌ capture/cpuinfo is gone; type 'reset' to get it back"
  exit 1
fi
want_workers=$(awk -F': *' '/^physical id/ { p = $2 } /^core id/ { c[p ":" $2] = 1 } END { print length(c) }' "$CPU")
if grep '^flags' "$CPU" | tr ' \t' '\n\n' | grep -qx avx2; then want_build=avx2; else want_build=generic; fi
threads=$(grep -c '^processor' "$CPU")
one_socket_ids=$(awk -F': *' '/^core id/ { c[$2] = 1 } END { print length(c) }' "$CPU")
per_socket=$(awk -F': *' '/^cpu cores/ { print $2; exit }' "$CPU")

if [ ! -f "$CONF" ]; then
  echo "❌ $CONF is missing"
  exit 1
fi
settings=$(tr -d '\r' < "$CONF" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^#' | grep -v '^$')
keys=$(printf '%s\n' "$settings" | sed 's/=.*//' | LC_ALL=C sort | paste -sd' ' -)
if [ "$keys" != "BUILD WORKERS" ]; then
  echo "❌ $CONF should set exactly two things, WORKERS= and BUILD= (one line each, comments are fine); it sets: ${keys:-nothing}"
  exit 1
fi
workers=$(printf '%s\n' "$settings" | sed -n 's/^WORKERS=//p' | tr -d '"'\''')
build=$(printf '%s\n' "$settings" | sed -n 's/^BUILD=//p' | tr -d '"'\''')

if [ "$workers" != "$want_workers" ]; then
  if [ "$workers" = "$threads" ]; then
    echo "❌ WORKERS=$workers counts processor entries, which include hyperthreads; one worker per physical core"
  elif [ "$workers" = "$one_socket_ids" ] || [ "$workers" = "$per_socket" ]; then
    echo "❌ WORKERS=$workers covers one socket only: every socket numbers its cores again, so count (physical id, core id) pairs"
  else
    echo "❌ WORKERS=$workers is not the number of physical cores in capture/cpuinfo"
  fi
  exit 1
fi
if [ "$build" != "$want_build" ]; then
  if [ "$build" = avx2 ]; then
    echo "❌ BUILD=avx2, but the new CPU has no avx2 flag (avx is not avx2: match the whole word)"
  elif [ "$build" = generic ]; then
    echo "❌ BUILD=generic, but the new CPU supports AVX2"
  else
    echo "❌ BUILD must be avx2 or generic"
  fi
  exit 1
fi

# The running service must have picked the new values up.
st=.lm/systemd/units/render-worker.service.state
if [ "$(bin/systemctl is-active render-worker.service 2>/dev/null)" != active ]; then
  echo "❌ $CONF is right, but render-worker.service is not running"
  exit 1
fi
envline=$(grep '^LMEnvironment=' "$st" 2>/dev/null)
if ! printf '%s' "$envline" | grep -q "\"WORKERS=$want_workers\"" || ! printf '%s' "$envline" | grep -q "\"BUILD=$want_build\""; then
  echo "❌ $CONF is right, but the running render-worker still has its old settings; it reads the file only when it starts"
  exit 1
fi

echo "✅ render-worker runs $want_workers workers with the $want_build build ($threads logical CPUs, $want_workers physical cores)"
exit 0
