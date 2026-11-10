SANDBOX="$1"
cd "$SANDBOX" || exit 1
if [ ! -s .lm-state/keep.lines ]; then echo "❌ the level's data is gone; type 'reset'"; exit 1; fi
[ -s drop.patterns ] || { echo "❌ drop.patterns is missing or empty"; exit 1; }
if grep -qx '' drop.patterns; then
  echo "❌ drop.patterns has an empty line, and an empty pattern matches every line"; exit 1
fi
orig=.lm-state/app.log.orig
grep -nvEf drop.patterns "$orig" > .lm-state/out 2>.lm-state/err
rc=$?
if [ "$rc" = 2 ] || [ -s .lm-state/err ]; then
  echo "❌ grep rejects drop.patterns: $(head -1 .lm-state/err | cut -c1-100)"; exit 1
fi
cut -d: -f1 .lm-state/out | sort > .lm-state/got.lines
# lines that should have been dropped but survive / lines that were lost
comm -13 .lm-state/keep.lines .lm-state/got.lines > .lm-state/leftover
comm -23 .lm-state/keep.lines .lm-state/got.lines > .lm-state/lost
nl=$(wc -l < .lm-state/lost)
nn=$(wc -l < .lm-state/leftover)
if [ "$nl" -gt 0 ]; then
  nerr=$(awk 'NR==FNR {l[$1]; next} (FNR in l) && $3=="ERROR"' .lm-state/lost "$orig" | wc -l)
  if [ "$nerr" -gt 0 ]; then
    echo "❌ your patterns drop $nerr ERROR line(s); an ERROR line must never be filtered out"
  else
    echo "❌ your patterns drop $nl line(s) that are not part of the three noisiest templates"
  fi
  exit 1
fi
if [ "$nn" -gt 0 ]; then
  echo "❌ $nn line(s) of the noisy templates still get through the filter"
  exit 1
fi
echo "✅ exactly the three noisiest templates are filtered out and every other line, every ERROR included, survives"
exit 0
