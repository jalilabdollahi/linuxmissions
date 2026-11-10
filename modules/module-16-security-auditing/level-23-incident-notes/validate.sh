#!/bin/bash
# Four persistence mechanisms removed with legitimate content intact, evidence kept, and
# iocs.txt naming the attacker IP and key fingerprint without any innocent IP or fingerprint.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
[ -s .lm-state/atk.ip ] || { echo "❌ internal state missing, type 'reset'"; exit 1; }
atk_ip=$(cat .lm-state/atk.ip); atk_fp=$(cat .lm-state/atk.fp)

sha256sum -c --quiet .lm-state/evidence.sha >/dev/null 2>&1 || { echo "❌ var/log/auth.log or the shell history was altered or deleted: keep the evidence, only remove the attacker's persistence"; exit 1; }

# 1. authorized_keys
[ -f home/deploy/.ssh/authorized_keys ] || { echo "❌ home/deploy/.ssh/authorized_keys is gone: legitimate keys must stay"; exit 1; }
now=$(ssh-keygen -lf home/deploy/.ssh/authorized_keys 2>/dev/null | awk '{print $2}' | LC_ALL=C sort)
[ -n "$now" ] || { echo "❌ authorized_keys holds no valid keys (ssh-keygen -lf cannot read it)"; exit 1; }
if echo "$now" | grep -qF "$atk_fp"; then echo "❌ the attacker's key is still in authorized_keys"; exit 1; fi
[ "$now" = "$(cat .lm-state/legit.fps)" ] || { echo "❌ authorized_keys does not hold exactly the three legitimate keys any more"; exit 1; }

# 2. cron
spool="$SANDBOX/var/spool/cron/crontabs"
cron=$(LM_CRON_SPOOL="$spool" LM_CRON_USER=deploy python3 "$MOCKS/cron/crontab" -l 2>/dev/null)
if echo "$cron" | grep -qF "$(cat .lm-state/blob)" || echo "$cron" | grep -q 'base64 -d'; then
  echo "❌ the beacon is still in deploy's crontab"; exit 1
fi
[ "$(echo "$cron" | grep -v '^$' | LC_ALL=C sort)" = "$(LC_ALL=C sort .lm-state/cron.legit)" ] || { echo "❌ deploy's crontab no longer holds exactly the legitimate entries (MAILTO and the two jobs)"; exit 1; }

# 3. .bashrc
[ -f home/deploy/.bashrc ] || { echo "❌ home/deploy/.bashrc is gone"; exit 1; }
if grep -q 'sysd' home/deploy/.bashrc; then echo "❌ .bashrc still contains the attacker's sudo alias"; exit 1; fi
grep -v '^$' home/deploy/.bashrc | cmp -s - .lm-state/bashrc.good || { echo "❌ .bashrc lost or changed something besides the attacker's alias (the lines after it count too)"; exit 1; }

# 4. SUID copy
[ ! -e home/deploy/.cache/.sysd/sh ] || { echo "❌ the SUID shell copy under home/ is still there"; exit 1; }
[ -f usr/bin/passwd ] && [ -u usr/bin/passwd ] || { echo "❌ the legitimate SUID usr/bin/passwd was removed or lost its setuid bit"; exit 1; }
other=$(find home -perm -4000 | head -1)
[ -z "$other" ] || { echo "❌ another setuid file is left: $other"; exit 1; }

# 5. IOCs
[ -s iocs.txt ] || { echo "❌ iocs.txt is missing or empty"; exit 1; }
grep -qF "$atk_ip" iocs.txt || { echo "❌ iocs.txt does not contain the attacker's IP address"; exit 1; }
grep -qF "$atk_fp" iocs.txt || { echo "❌ iocs.txt does not contain the fingerprint of the key the attacker added"; exit 1; }
while IFS= read -r d; do
  grep -qF "$d" iocs.txt && { echo "❌ iocs.txt lists $d, which belongs to a legitimate user, the scanner or a legitimate key"; exit 1; }
done < .lm-state/decoys
echo "✅ all four backdoors are gone, legitimate access is intact, evidence kept and the IOCs are recorded"
exit 0
