SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/pids ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
tar=$(awk '$1=="tar" {print $2}' .lm-state/pids); gz=$(awk '$1=="gzip" {print $2}' .lm-state/pids); db=$(awk '$1=="db" {print $2}' .lm-state/pids)
for x in "tar $tar" "gzip $gz" "db $db"; do
  set -- $x
  if ! kill -0 "$2" 2>/dev/null || [ "$(ps -o stat= -p "$2" | cut -c1)" = Z ]; then
    echo "❌ the $1 process (PID $2) is gone; nothing may be stopped or killed (type 'reset' to start over)"
    exit 1
  fi
  if [ "$(ps -o stat= -p "$2" | cut -c1)" = T ]; then
    echo "❌ the $1 process (PID $2) is stopped; the backup has to keep running"
    exit 1
  fi
done
if [ "$(ionice -p "$db" 2>/dev/null)" != "$(cat .lm-state/db.io)" ]; then
  echo "❌ the database's I/O class was changed ($(ionice -p "$db" 2>/dev/null)); only the backup may be put in the idle class"
  exit 1
fi
tc=$(ionice -p "$tar" 2>/dev/null); gc=$(ionice -p "$gz" 2>/dev/null)
case "$tc" in idle*) ;; *) tc_bad=1;; esac
case "$gc" in idle*) ;; *) gc_bad=1;; esac
if [ -n "$tc_bad" ] && [ -n "$gc_bad" ]; then
  echo "❌ neither the tar process (I/O class: ${tc%%,*}) nor the gzip compressor below it (${gc%%,*}) is in the idle class yet"
  exit 1
fi
if [ -n "$gc_bad" ]; then
  echo "❌ tar (PID $tar) is idle, but the gzip compressor below it (PID $gz), the process that does the writing, still has I/O class '${gc%%,*}'; children do not follow a later change to their parent, and tar's helpers are not direct children"
  exit 1
fi
if [ -n "$tc_bad" ]; then
  echo "❌ gzip is idle, but its ancestor tar (PID $tar) still has I/O class '${tc%%,*}'"
  exit 1
fi
echo "✅ tar and gzip run in the idle I/O class, still alive; the database kept its class"
exit 0
