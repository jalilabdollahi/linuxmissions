#!/bin/bash
# crashed_boot.txt = the _BOOT_ID with no systemd-shutdown "Powering off."/"Rebooting.";
# crash_errors.txt = that boot's PRIORITY 0-3 messages in __REALTIME_TIMESTAMP order.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
if ! cksum journal.json 2>/dev/null | cmp -s - .lm-state/sum; then
  echo "❌ journal.json was changed; type 'reset' to get it back"
  exit 1
fi
[ -f crashed_boot.txt ] || { echo "❌ crashed_boot.txt does not exist yet"; exit 1; }
[ -f crash_errors.txt ] || { echo "❌ crash_errors.txt does not exist yet"; exit 1; }
python3 - <<'PYEOF'
import sys
want_id = open(".lm-state/crashed_boot").read().strip()
ids = open(".lm-state/boot_ids").read().split()
got_id = open("crashed_boot.txt").read().strip()
if "\n" in got_id or not got_id:
    print("❌ crashed_boot.txt must hold exactly one boot ID"); sys.exit(1)
if got_id != want_id:
    if got_id in ids:
        print("❌ crashed_boot.txt names a boot that ended with a clean shutdown message")
    else:
        print("❌ crashed_boot.txt is not a _BOOT_ID that appears in journal.json")
    sys.exit(1)
want = open(".lm-state/crash_errors").read().splitlines()
got = open("crash_errors.txt").read().splitlines()
if got == want:
    print("✅ boot %s crashed, and its %d error messages are in time order" % (got_id[:8], len(want)))
    sys.exit(0)
if not got:
    print("❌ crash_errors.txt is empty"); sys.exit(1)
if sorted(got) == sorted(want):
    print("❌ the right messages, but not in time order (journal.json is not sorted)"); sys.exit(1)
extra = [m for m in got if m not in want]
missing = [m for m in want if m not in got]
if extra:
    print("❌ crash_errors.txt has %d line(s) that are not error-or-worse messages of that boot (e.g. wrong boot or a warning)" % len(extra))
elif missing:
    print("❌ crash_errors.txt has %d line(s), expected more: some errors of that boot are missing (check both PRIORITY 0-3)" % len(got))
else:
    print("❌ crash_errors.txt has the wrong number of lines (%d), check for duplicates" % len(got))
sys.exit(1)
PYEOF
