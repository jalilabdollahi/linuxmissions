#!/bin/bash
# First Match Wins. etc/ssh/sshd_config already says the right things, but
# drop-ins that are Included first and a `Match User deploy` block override
# them (first value wins in the global section; Match overrides apply later).
# Which drop-in carries which override is random. A *.conf.disabled decoy is
# not matched by the Include glob. Effective output (via the shared mock
# sshd) for four connection contexts is stored so the validator can check
# that nothing else changed.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf etc .lm-state bin; mkdir -p etc/ssh/sshd_config.d .lm-state bin
MOCK="$(cd "$(dirname "$0")/../../../mocks/security" && pwd)"
cp "$MOCK/sshd" bin/sshd; chmod 755 bin/sshd

D=etc/ssh/sshd_config.d
files=("$D/10-legacy-access.conf" "$D/50-cloud-init.conf" "$D/60-tuning.conf")
for f in "${files[@]}"; do : > "$f"; done
pick_file() { echo "${files[RANDOM % 3]}"; }
tries=$((7 + RANDOM % 6))
echo "PermitRootLogin yes"        >> "$(pick_file)"
echo "PasswordAuthentication yes" >> "$(pick_file)"
echo "MaxAuthTries $tries"        >> "$(pick_file)"

# harmless settings that must survive
printf '%s\n' "# vendor: keep idle sessions alive" "ClientAliveInterval 300" >> "${files[0]}"
printf '%s\n' "# cloud-init generated" "UsePAM yes" >> "${files[1]}"
printf '%s\n' "# tuning" "LogLevel VERBOSE" "MaxSessions 4" >> "${files[2]}"
# the file the Include glob does not match
printf '# old settings, disabled in 2024\nPermitRootLogin yes\nPasswordAuthentication yes\n' > "$D/99-old.conf.disabled"

cat > etc/ssh/sshd_config <<'CONF'
# /etc/ssh/sshd_config - web-02
Include sshd_config.d/*.conf

Port 22
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Authentication (set by the hardening playbook)
PermitRootLogin no
PasswordAuthentication no
MaxAuthTries 3
PubkeyAuthentication yes
X11Forwarding no

AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Nightly backups come in with one key and may only run the backup wrapper
Match User backup
    ForceCommand /usr/local/bin/backup-only
    AllowTcpForwarding no

# The deploy user comes from the CI runners
Match User deploy
    PasswordAuthentication yes
    AllowTcpForwarding no
    MaxSessions 20

# Staff on the office network may forward X11 and use agents
Match Address 10.0.0.0/8
    X11Forwarding yes
    AllowAgentForwarding yes
CONF

# four connection contexts, as the validator will query them
cat > .lm-state/contexts <<'CTX'
user=deploy,host=ci-runner,addr=192.0.2.10
user=backup,host=nas,addr=10.2.3.4
user=alice,host=laptop,addr=10.2.3.5
user=alice,host=home,addr=203.0.113.9
CTX
i=0
while IFS= read -r c; do
  i=$((i + 1))
  bin/sshd -T -f etc/ssh/sshd_config -C "$c" > ".lm-state/baseline.$i" || exit 1
done < .lm-state/contexts
