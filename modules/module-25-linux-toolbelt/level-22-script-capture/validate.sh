#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
st=.lm-state
tok=$(cat $st/token)
[ -f diag.typescript ] || { echo "❌ diag.typescript does not exist yet"; exit 1; }
if ! grep -aq "session-token: $tok" diag.typescript; then
  echo "❌ diag.typescript does not contain the report: the tool only prints it when it runs on a terminal"; exit 1
fi
if ! grep -aq "$(printf '\033')" diag.typescript; then
  echo "❌ diag.typescript has no raw terminal output (no colour codes): it should be a real recording of the tool's run"; exit 1
fi
[ -f diag.txt ] || { echo "❌ the recording is fine, but diag.txt does not exist yet"; exit 1; }
if grep -aq "$(printf '\033')" diag.txt; then echo "❌ diag.txt still contains escape (colour/erase) codes"; exit 1; fi
if grep -aq "$(printf '\r')" diag.txt; then echo "❌ diag.txt still contains carriage returns"; exit 1; fi
if grep -aq '^Script ' diag.txt; then echo "❌ diag.txt still has the Script started/done lines the recorder adds"; exit 1; fi
if grep -aq 'collecting' diag.txt; then echo "❌ diag.txt still has spinner frames ('collecting data ...') that a person never saw on screen"; exit 1; fi
if cmp -s diag.txt $st/expected.txt; then
  echo "✅ a real typescript was recorded and diag.txt is the clean report"; exit 0
fi
n=$(grep -c . diag.txt)
want=$(grep -c . $st/expected.txt)
[ "$n" -eq "$want" ] || { echo "❌ diag.txt has $n lines, the report on screen has $want"; exit 1; }
l=$(diff diag.txt $st/expected.txt | grep -m1 '^[0-9]' | sed 's/[^0-9].*//')
echo "❌ line $l of diag.txt differs from the report as it appeared on screen (stray spaces or characters?)"; exit 1
