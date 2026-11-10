#!/bin/bash
# alert.sms: every line <= 70 chars; joined per original paragraph it equals the
# original line; a break inside a word is allowed only inside the long URL.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
orig=.lm-state/alert.orig
if ! cmp -s alert.txt "$orig"; then echo "❌ alert.txt was changed; type 'reset' to restore it"; exit 1; fi
if [ ! -f alert.sms ]; then echo "❌ alert.sms does not exist yet"; exit 1; fi

long=$(awk 'length($0) > 70' alert.sms | wc -l | tr -d ' ')
if [ "$long" -gt 0 ]; then
  echo "❌ $long line(s) of alert.sms are longer than 70 characters (the longest has $(awk '{ if (length($0) > m) m = length($0) } END { print m }' alert.sms))"; exit 1
fi
awk '
function fail(msg) { print msg; bad = 1; exit 1 }
BEGIN { idx = 1 }
NR == FNR { P[++np] = $0; next }
{
  if (idx > np) fail("❌ alert.sms has more text than alert.txt")
  if (buf != "") {
    # a break between the previous line and this one, inside paragraph idx
    if (substr(prev, length(prev), 1) != " " && substr($0, 1, 1) != " ") {
      s = index(P[idx], "https://"); e = 0
      if (s > 0) { rest = substr(P[idx], s); sp = index(rest, " "); e = s + (sp ? sp - 1 : length(rest)) }
      pos = length(buf)
      if (!(s > 0 && pos >= s && pos < e - 1)) fail("❌ a word was cut in the middle near \"" substr(prev, length(prev) - 8) "|" substr($0, 1, 8) "\": break at spaces where you can")
    }
  }
  buf = buf $0; prev = $0
  if (buf == P[idx]) { idx++; buf = ""; prev = "" }
  else if (length(buf) >= length(P[idx]) || index(P[idx], buf) != 1)
    fail("❌ alert.sms no longer matches alert.txt in paragraph " idx " (text lost, changed, or spaces removed)")
}
END { if (!bad && (buf != "" || idx <= np)) { print "❌ alert.sms ends before all of alert.txt is there"; exit 1 } }
' "$orig" alert.sms || exit 1
echo "✅ alert.sms: $(wc -l < alert.sms | tr -d ' ') lines of at most 70 characters, words intact, text unchanged"
exit 0
