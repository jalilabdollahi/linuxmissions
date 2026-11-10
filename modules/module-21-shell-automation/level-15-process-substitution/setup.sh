#!/bin/bash
# Stale Accounts: stale_accounts.sh compares the server's account export with
# the HR roster. The draft writes temp files (the audit job has no writable
# temp dir), counts inside `cmd | while` (a subshell, so TOTAL stays 0), and
# compares lowercase logins with HR's uppercase ones.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

# login:uid, as exported from the server (getent passwd | cut -d: -f1,3)
cat > users.export <<'TXT'
root:0
daemon:1
www-data:33
backup:34
amira.haddad:1004
bkovacs:1001
cnwosu:1012
deploy:998
dpetrova:1003
egarcia:1009
fokafor:1015
gtanaka:1002
hlindqvist:1011
ijensen:1006
jmorales:1013
kwright:1007
lchen:1010
mrossi:1014
nobody:65534
oadeyemi:1008
pnovak:1005
TXT

cat > hr_roster.csv <<'TXT'
employee_id,login,status,full_name
E1001,BKOVACS,active,Bence Kovacs
E1002,GTANAKA,active,Gen Tanaka
E1003,DPETROVA,leave,Daria Petrova
E1004,AMIRA.HADDAD,active,Amira Haddad
E1005,PNOVAK,terminated,Petr Novak
E1006,IJENSEN,active,Ida Jensen
E1007,KWRIGHT,terminated,"Wright, Kim"
E1008,OADEYEMI,active,Ola Adeyemi
E1009,EGARCIA,active,Elena Garcia
E1011,HLINDQVIST,leave,Hanna Lindqvist
E1012,CNWOSU,active,"Nwosu, Chidi"
E1014,MROSSI,active,Marco Rossi
TXT

cat > stale_accounts.sh <<'SCRIPT'
#!/bin/bash
# stale_accounts.sh USERS_EXPORT HR_ROSTER
# Prints the accounts to disable, sorted, one per line, then "TOTAL n".
sys=$(mktemp)
hr=$(mktemp)
cut -d: -f1 "$1" | sort > "$sys"
grep -v ',terminated,' "$2" | cut -d, -f2 | sort > "$hr"

count=0
comm -23 "$sys" "$hr" | while read -r login; do
  echo "$login"
  count=$((count + 1))
done
echo "TOTAL $count"
rm -f "$sys" "$hr"
SCRIPT
chmod +x stale_accounts.sh

cat > AUDIT.txt <<'TXT'
Quarterly access audit
- Human accounts on the server have uid 1000 to 59999. Lower uids (root,
  daemon, deploy, ...) and nobody (65534) are system accounts: never list them.
- An account stays when HR has its login with status active or leave
  (HR writes logins in capitals). Every other human account must be disabled:
  no HR row at all, or status terminated.
- The audit runner starts the script in a read-only directory and its temp
  directory ($TMPDIR) is not writable either: the script cannot create files.
TXT
