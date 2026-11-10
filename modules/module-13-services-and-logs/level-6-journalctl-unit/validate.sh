#!/bin/bash
# payment.txt = the messages (no prefix) of every journal entry of
# payment.service, including systemd's own lines about it, inside the window
# from TICKET.txt, oldest first. Computed with the shared mock from the
# journal; no entry is near either end of the window, so --until being
# inclusive or not makes no difference.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
JC="$(dirname "$0")/../../../mocks/systemd/journalctl"
export LM_ROOT="$SANDBOX"
FILE=payment.txt

if [ ! -s .lm/window ] || [ ! -s .lm/journal.sum ] || ! cksum var/log/journal/system.json 2>/dev/null | cmp -s - .lm/journal.sum; then
  echo "❌ the journal in var/log/journal (or the level's data in .lm/) was changed; type 'reset' to restore it"
  exit 1
fi
if [ ! -f "$FILE" ]; then
  echo "❌ payment.txt does not exist yet"
  exit 1
fi
FROM=$(sed -n 1p .lm/window)
TO=$(sed -n 2p .lm/window)

q() { "$JC" -o cat "$@" 2>/dev/null | grep -v '^-- No entries --$'; }
GOT=$(tr -d '\r' < "$FILE" | sed -E 's/[[:space:]]+$//' | awk 'NF')
EXP=$(q -u payment.service --since "$FROM" --until "$TO")

if [ "$GOT" = "$EXP" ]; then
  echo "✅ payment.txt holds the $(printf '%s\n' "$EXP" | wc -l | tr -d ' ') messages of payment.service in the incident window, systemd's lines included"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ payment.txt is empty"
  exit 1
fi
if printf '%s\n' "$GOT" | grep -Eq '^(Nov [ 0-9][0-9] [0-9:]{8}|20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9:]{8})'; then
  echo "❌ the ticket wants messages only: no timestamp, host or identifier in front"
  exit 1
fi
has_any() { [ -n "$1" ] && printf '%s\n' "$GOT" | grep -Fxq -f <(printf '%s\n' "$1"); }
OTHER=$(q -u payment-sync.service -u 'payment@eu.service' --since "$FROM" --until "$TO" | grep -Fxv -f <(printf '%s\n' "$EXP"))
if has_any "$OTHER"; then
  echo "❌ payment.txt has lines of other units (payment-sync.service or payment@eu.service); only payment.service is wanted"
  exit 1
fi
OUTSIDE=$(q -u payment.service | grep -Fxv -f <(printf '%s\n' "$EXP"))
if has_any "$OUTSIDE"; then
  echo "❌ payment.txt has payment.service lines from outside the window $FROM to $TO"
  exit 1
fi
NOISE=$(q --since "$FROM" --until "$TO" | grep -Fxv -f <(printf '%s\n' "$EXP"))
if has_any "$NOISE"; then
  echo "❌ payment.txt has lines that don't belong to payment.service"
  exit 1
fi
SYSD=$(q -u payment.service --since "$FROM" --until "$TO" _PID=1)
if [ -n "$SYSD" ] && ! has_any "$SYSD"; then
  echo "❌ systemd's own lines about payment.service (Stopping..., Started..., Consumed ...) are part of its log too"
  exit 1
fi
if [ "$(printf '%s\n' "$GOT" | sort)" = "$(printf '%s\n' "$EXP" | sort)" ]; then
  echo "❌ the right lines, but not in journal order (oldest first)"
  exit 1
fi
missing=$(printf '%s\n' "$EXP" | grep -Fxv -f <(printf '%s\n' "$GOT") | wc -l | tr -d ' ')
if [ "$missing" = 0 ]; then
  echo "❌ payment.txt has $(printf '%s\n' "$GOT" | wc -l | tr -d ' ') lines, but payment.service logged $(printf '%s\n' "$EXP" | wc -l | tr -d ' ') in the window: some lines are extra or repeated"
  exit 1
fi
echo "❌ payment.txt misses $missing of payment.service's lines in the window (all of its processes count, whatever name they log under)"
exit 1
