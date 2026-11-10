SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/procs ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
while read -r pid role name ni0; do
  now=$(ps -o ni= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -z "$now" ]; then echo "❌ $name (PID $pid) is gone; the workers must keep running (type 'reset' to start over)"; exit 1; fi
  st=$(ps -o stat= -p "$pid" | cut -c1)
  if [ "$st" = T ]; then echo "❌ $name (PID $pid) is stopped, it must keep running"; exit 1; fi
  case $role in
    violator)
      if [ "$now" -lt 15 ] && [ "$now" -ge "$ni0" ] && [ "$now" = "$ni0" ]; then
        echo "❌ $name (PID $pid) still has niceness $now; every batch worker below 10 needs 15$( [ "$name" = batch-etl-extract ] || [ "$name" = batch-etl-load ] && echo ' (this one belongs to the batch-etl pipeline: all its processes count)')"
        exit 1
      fi
      if [ "$now" != 15 ]; then echo "❌ $name (PID $pid) has niceness $now, expected exactly 15"; exit 1; fi;;
    *)
      if [ "$now" != "$ni0" ]; then
        echo "❌ $name (PID $pid) had niceness $ni0 and now has $now; it was not a violator and must stay as it was$( [ "$role" = api ] && echo ' (renice -u hits every process of a user, including the API)')"
        exit 1
      fi;;
  esac
done < .lm-state/procs
echo "✅ all batch workers below 10 are at niceness 15; the API, the agent and the compliant workers are untouched"
exit 0
