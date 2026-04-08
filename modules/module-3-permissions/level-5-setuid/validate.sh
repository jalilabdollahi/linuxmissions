#!/bin/bash
SANDBOX="$1"
if [ ! -f "$SANDBOX/suid_files.txt" ]; then
  echo "❌ FAIL: suid_files.txt not found"; exit 1
fi
if grep -q "special_tool" "$SANDBOX/suid_files.txt" && grep -q "group_tool" "$SANDBOX/suid_files.txt"; then
  echo "✅ PASS: suid_files.txt correctly identifies special_tool (SUID) and group_tool (SGID)"
  exit 0
fi
echo "❌ FAIL: suid_files.txt should contain both special_tool and group_tool"
exit 1
