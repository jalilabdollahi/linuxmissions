#!/bin/bash
# One-Shot Task: a mock at/atq/atrm with a frozen clock (Mon 2024-04-08 14:30).
# A colleague queued cleanup.sh for 03:30 tomorrow, which collides with the
# nightly backup; it must run tonight at 23:30 instead. Job 2 is unrelated
# and must stay.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p var/spool/at

cat > cleanup.sh <<'EOF'
#!/bin/bash
# Removes the old release directories left behind by the migration.
echo "cleanup: removed old releases"
EOF
cat > rotate-certs.sh <<'EOF'
#!/bin/bash
echo "certificates rotated"
EOF
chmod +x cleanup.sh rotate-certs.sh

printf 'time=2024-04-10 02:00\ncwd=%s\n./rotate-certs.sh\n' "$SANDBOX" > var/spool/at/job2
printf 'time=2024-04-09 03:30\ncwd=%s\n./cleanup.sh\n' "$SANDBOX" > var/spool/at/job3
echo 3 > var/spool/at/.SEQ

# ------------------------------------------------------------------ at
cat > at <<'SCRIPT'
#!/bin/bash
# Mock at for LinuxMissions. Not the real atd: jobs are stored in
# ./var/spool/at and never run; the clock is frozen at Mon 2024-04-08 14:30.
# Usage: at [-f FILE] TIMESPEC | at -l | at -r JOB... | at -c JOB
# TIMESPEC: now [+ N minutes|hours|days|weeks], HH:MM, HHMM, 11:30pm, noon,
# midnight, teatime, optionally followed by today, tomorrow, YYYY-MM-DD,
# or + N units.
ROOT="$(cd "$(dirname "$0")" && pwd)"
SPOOL="$ROOT/var/spool/at"
NOW=870   # minutes since 2024-04-08 00:00

fmt() {  # minutes since 2024-04-08 00:00 -> "Mon Apr  8 23:30:00 2024"
  awk -v m="$1" 'BEGIN {
    split("Sun Mon Tue Wed Thu Fri Sat", dn, " ")
    d = int(m / 1440); day = 8 + d; mon = "Apr"
    if (day > 30) { day -= 30; mon = "May" }
    printf "%s %s %2d %02d:%02d:00 2024\n", dn[(1 + d) % 7 + 1], mon, day, int(m % 1440 / 60), m % 60 }'
}
to_iso() {
  awk -v m="$1" 'BEGIN { d = int(m / 1440); day = 8 + d; mon = 4; if (day > 30) { day -= 30; mon = 5 }
    printf "2024-%02d-%02d %02d:%02d\n", mon, day, int(m % 1440 / 60), m % 60 }'
}
from_iso() {
  awk -v t="$1" 'BEGIN { mon = substr(t, 6, 2) + 0; day = substr(t, 9, 2) + 0; if (mon == 5) day += 30
    print (day - 8) * 1440 + substr(t, 12, 2) * 60 + substr(t, 15, 2) }'
}

list_jobs() {
  local user="${USER:-$(id -un 2>/dev/null)}"
  for f in "$SPOOL"/job*; do
    [ -f "$f" ] || continue
    t="$(sed -n 's/^time=//p' "$f")"
    printf '%s\t%s\t%s a %s\n' "$(from_iso "$t")" "${f##*/job}" "$(fmt "$(from_iso "$t")")" "$user"
  done | sort -t "$(printf '\t')" -k1,1n -k2,2n | cut -f2-
}

case "${1:-}" in
  -l) list_jobs; exit 0 ;;
  -r|-d)
    shift; [ $# -gt 0 ] || { echo "Usage: atrm JOB..." >&2; exit 1; }
    rc=0
    for j in "$@"; do
      if [ -f "$SPOOL/job$j" ]; then rm -f "$SPOOL/job$j"; else echo "Cannot find jobid $j" >&2; rc=1; fi
    done
    exit $rc ;;
  -c)
    j="${2:-}"; f="$SPOOL/job$j"
    [ -n "$j" ] && [ -f "$f" ] || { echo "Cannot find jobid $j" >&2; exit 1; }
    echo "#!/bin/sh"
    echo "# atrun uid=$(id -u) gid=$(id -g)"
    echo "umask 22"
    echo "cd $(sed -n 's/^cwd=//p' "$f") || {"
    echo "	 echo 'Execution directory inaccessible' >&2"
    echo "	 exit 1"
    echo "}"
    sed '1,2d' "$f"
    exit 0 ;;
esac

file=""
if [ "${1:-}" = "-f" ]; then
  file="${2:-}"; shift 2 || { echo "at: option requires an argument -- 'f'" >&2; exit 1; }
  [ -r "$file" ] || { echo "at: cannot open input file $file: No such file or directory" >&2; exit 1; }
fi
[ $# -gt 0 ] || { echo "Garbled time" >&2; exit 1; }

# Parse the time spec into minutes since 2024-04-08 00:00.
when="$(printf '%s ' "$@" | tr 'A-Z' 'a-z' | sed -E 's/\+/ + /g; s/([0-9])([a-z])/\1 \2/g; s/ (am|pm)/\1/g' | awk -v now="$NOW" '
  function unit(u) {
    if (u ~ /^(min|mins|minute|minutes)$/) return 1
    if (u ~ /^(hour|hours)$/) return 60
    if (u ~ /^(day|days)$/) return 1440
    if (u ~ /^(week|weeks)$/) return 10080
    return 0
  }
  {
    n = split($0, w, " "); i = 1; t = -1; dayset = 0
    if (w[i] == "now") { t = now; dayset = 1; i++ }
    else if (w[i] == "noon") { t = 720; i++ }
    else if (w[i] == "midnight") { t = 0; i++ }
    else if (w[i] == "teatime") { t = 960; i++ }
    else if (w[i] ~ /^[0-9]{1,2}(:[0-9]{2})?(am|pm)?$/ || w[i] ~ /^[0-9]{4}$/) {
      s = w[i]; ap = ""
      if (s ~ /(am|pm)$/) { ap = substr(s, length(s) - 1); s = substr(s, 1, length(s) - 2) }
      if (s ~ /^[0-9]{4}$/) { h = substr(s, 1, 2) + 0; m = substr(s, 3, 2) + 0 }
      else if (index(s, ":")) { h = substr(s, 1, index(s, ":") - 1) + 0; m = substr(s, index(s, ":") + 1) + 0 }
      else if (ap != "") { h = s + 0; m = 0 }
      else { print "ERR " w[i]; exit }
      if (ap != "") { if (h < 1 || h > 12) { print "ERR " w[i]; exit } if (h == 12) h = 0; if (ap == "pm") h += 12 }
      if (h > 23 || m > 59) { print "ERR " w[i]; exit }
      t = h * 60 + m; i++
    } else { print "ERR " w[i]; exit }
    if (i <= n && w[i] == "today") { dayset = 1; i++ }
    else if (i <= n && w[i] == "tomorrow") { t += 1440; dayset = 1; i++ }
    else if (i <= n && w[i] ~ /^2024-0[45]-[0-9]{2}$/) {
      mon = substr(w[i], 6, 2) + 0; d = substr(w[i], 9, 2) + 0; if (mon == 5) d += 30
      t += (d - 8) * 1440; dayset = 1; i++
    }
    if (!dayset && t <= now) t += 1440
    if (i <= n && w[i] == "+") {
      if (i + 2 > n || w[i + 1] !~ /^[0-9]+$/ || unit(w[i + 2]) == 0) { print "ERR " w[i + 1]; exit }
      t += w[i + 1] * unit(w[i + 2]); i += 3
    }
    if (i <= n) { print "ERR " w[i]; exit }
    if (t < now) { print "PAST"; exit }
    if (t > 40 * 1440) { print "ERR " $0; exit }
    print t
  }')"

case "$when" in
  ERR*) echo "syntax error. Last token seen: ${when#ERR }" >&2; echo "Garbled time" >&2; exit 1 ;;
  PAST) echo "at: refusing to create job destined in the past" >&2; exit 1 ;;
esac

if [ -n "$file" ]; then
  cmds="$(cat "$file")"
elif [ -t 0 ]; then
  echo "at (mock): type-in mode is not available in this sandbox; give the commands on" >&2
  echo "standard input instead, e.g.:  echo './script.sh' | ./at 18:00" >&2
  exit 1
else
  cmds="$(cat)"
fi
if [ -z "$(printf '%s' "$cmds" | tr -d '[:space:]')" ]; then
  echo "at: no commands given" >&2; exit 1
fi

seq=$(( $(cat "$SPOOL/.SEQ" 2>/dev/null || echo 0) + 1 ))
echo "$seq" > "$SPOOL/.SEQ"
{ echo "time=$(to_iso "$when")"; echo "cwd=$(pwd)"; printf '%s\n' "$cmds"; } > "$SPOOL/job$seq"
echo "warning: commands will be executed using /bin/sh" >&2
echo "job $seq at $(fmt "$when")" >&2
SCRIPT

cat > atq <<'SCRIPT'
#!/bin/bash
# Mock atq for LinuxMissions: lists the jobs queued with ./at.
exec "$(dirname "$0")/at" -l
SCRIPT
cat > atrm <<'SCRIPT'
#!/bin/bash
# Mock atrm for LinuxMissions: removes jobs queued with ./at.
exec "$(dirname "$0")/at" -r "$@"
SCRIPT
chmod +x at atq atrm
