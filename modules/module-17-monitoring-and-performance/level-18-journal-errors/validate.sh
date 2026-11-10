SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/answer ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s spike.txt ] || { echo "❌ spike.txt is missing or empty"; exit 1; }
read -r want_t want_u < .lm-state/answer
read -r t u extra < spike.txt
if [ -z "$t" ] || [ -z "$u" ] || [ -n "$extra" ]; then
  echo "❌ spike.txt must be one line: HH:MM unit"; exit 1
fi
if ! echo "$t" | grep -qE '^([01][0-9]|2[0-3]):[0-5][0-9]$'; then
  echo "❌ '$t' is not a time in HH:MM form"; exit 1
fi
if [ "$t" != "$want_t" ]; then
  # tell the player whether the minute at least had a real burst
  n=$(jq -r 'select((.PRIORITY|tonumber)<=3) | .__REALTIME_TIMESTAMP|tonumber/1000000|floor|strftime("%H:%M")' journal.json | grep -cx "$t")
  echo "❌ the minute $t is not the first minute with more than 10 errors (it has $n error entries; remember UTC and that priority 3 or lower is an error)"
  exit 1
fi
if [ "$u" != "$want_u" ]; then
  echo "❌ the minute is right, but $u did not log the most errors in it (count errors per unit within that minute only)"
  exit 1
fi
echo "✅ $want_t UTC, and $want_u was behind it"
exit 0
