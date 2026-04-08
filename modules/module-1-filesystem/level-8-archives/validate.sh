#!/bin/bash
SANDBOX="$1"
FAIL=0

# Check extraction
if [ ! -d "$SANDBOX/extracted" ]; then
  echo "❌ FAIL: extracted/ directory not found"
  FAIL=1
else
  if find "$SANDBOX/extracted" -name "app.txt" | grep -q .; then
    echo "✅ extracted/app.txt found"
  else
    echo "❌ FAIL: app.txt not in extracted/"
    FAIL=1
  fi
fi

# Check archive
if [ ! -f "$SANDBOX/archive.tar.gz" ]; then
  echo "❌ FAIL: archive.tar.gz not found"
  FAIL=1
else
  LOG_COUNT=$(tar -tzf "$SANDBOX/archive.tar.gz" 2>/dev/null | grep -c "\.log$" || echo 0)
  if [ "$LOG_COUNT" -ge 3 ]; then
    echo "✅ archive.tar.gz contains $LOG_COUNT .log files"
  else
    echo "❌ FAIL: archive.tar.gz has $LOG_COUNT .log files, expected 3"
    FAIL=1
  fi
fi

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
