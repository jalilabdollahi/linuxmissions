#!/bin/bash
# Quarantine Sweep: 200 text files in nested folders, some with spaces or an
# apostrophe in the name. Six contain the leaked NEBULA_KEY; two decoys
# contain nebula_key / NEBULA-KEY. Plain `| xargs mv` breaks on those names.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p files/2024-01 files/2024-02 "files/shared docs" "files/archive/old reports" quarantine

for i in $(seq -w 1 50); do
  echo "routine log entry $i, nothing to see" > "files/2024-01/note-$i.txt"
  echo "config snapshot $i: timeout=30 retries=3" > "files/2024-02/config-backup-$i.txt"
  echo "minutes of meeting $i: action items assigned" > "files/shared docs/meeting notes $i.txt"
  echo "monthly report $i: all green" > "files/archive/old reports/report-$i.txt"
done
echo "Q1 plan: hire two SREs" > "files/shared docs/Q1 plan.txt"
echo "export by dana: 1532 rows" > "files/archive/old reports/dana's export.txt"

# The leaked key, in six places.
printf 'debug dump\nNEBULA_KEY=nk_live_7f3a9c2e\n' >> "files/2024-01/note-17.txt"
printf 'NEBULA_KEY=nk_live_7f3a9c2e\n' >> "files/2024-02/config-backup-03.txt"
printf 'pasted by mistake: NEBULA_KEY=nk_live_7f3a9c2e\n' >> "files/shared docs/meeting notes 12.txt"
printf 'see NEBULA_KEY in vault\n' >> "files/shared docs/Q1 plan.txt"
printf 'NEBULA_KEY=nk_live_7f3a9c2e\n' >> "files/archive/old reports/dana's export.txt"
printf 'env: NEBULA_KEY=nk_live_7f3a9c2e\n' >> "files/archive/old reports/report-44.txt"

# Decoys: not the exact string.
printf 'rename nebula_key to vault path\n' >> "files/2024-01/note-08.txt"
printf 'the NEBULA-KEY project kickoff\n' >> "files/shared docs/meeting notes 30.txt"
