#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# Every file that does not end in .tmp must still be there, unchanged.
check() {  # path expected-content
  if [ ! -f "$1" ]; then
    echo "❌ $1 was deleted, but its name does not end in .tmp; type 'reset' and try again"
    exit 1
  fi
  if [ "$(cat "$1")" != "$2" ]; then
    echo "❌ $1 was modified; type 'reset' and try again"
    exit 1
  fi
}
check build/obj/main.o 'int main(void) { return 0; }'
check "build/page cache/index.html" '<html>cached page</html>'
check templates/invoice.tmpl 'Dear {{name}}, your invoice is attached.'
check templates/welcome.tmpl 'Hello {{name}}!'
check jobs/2024/q1/summary.csv $'job,status\n0107,failed\n0213,failed'
check jobs/2024/q2/README 'q2 jobs are archived monthly'
check reports/notes.tmp.txt 'Remember: .tmp files are safe to delete.'
check home/alice/.cache/editor/settings 'set number'

left=$(find . -type f -name '*.tmp' | wc -l | tr -d ' ')
if [ "$left" -gt 0 ]; then
  echo "❌ $left .tmp file(s) are still somewhere in the tree"
  exit 1
fi
echo "✅ all .tmp files are gone and every other file is intact"
exit 0
