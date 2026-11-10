#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
st=.lm-state
[ -f summary.txt ] || { echo "❌ summary.txt does not exist yet"; exit 1; }
if cmp -s summary.txt $st/expected; then
  echo "✅ summary.txt answers all three questions"; exit 0
fi
n=$(grep -c . summary.txt)
[ "$n" -eq 3 ] || { echo "❌ summary.txt must have exactly three lines (errors, kernel, setting), it has $n"; exit 1; }
for f in errors kernel setting; do
  grep -q "^$f: " summary.txt || { echo "❌ there is no '$f: ...' line in summary.txt"; exit 1; }
done
want=$(sed -n 's/^errors: //p' $st/expected); got=$(sed -n 's/^errors: //p' summary.txt)
[ "$got" = "$want" ] || { echo "❌ errors: $got is not the number of ERROR lines in the service log (is the log decoded into text you can search?)"; exit 1; }
want=$(sed -n 's/^kernel: //p' $st/expected); got=$(sed -n 's/^kernel: //p' summary.txt)
[ "$got" = "$want" ] || { echo "❌ kernel: '$got' is not the version in the kernel log's 'Linux version' line (the note in the mail is not the kernel log)"; exit 1; }
want=$(sed -n 's/^setting: //p' $st/expected); got=$(sed -n 's/^setting: //p' summary.txt)
[ "$got" = "$want" ] || { echo "❌ setting: '$got' is not the recommended setting from the text part (format key=value)"; exit 1; }
echo "❌ the three values are right, but the lines must be in the order errors, kernel, setting"; exit 1
