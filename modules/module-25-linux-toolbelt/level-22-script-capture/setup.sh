#!/bin/bash
# ./vendor-diag refuses to run unless stdout is a terminal, draws a spinner
# with \r, colours with ANSI codes, and prints a report with a random token.
# .lm-state/expected.txt is what the clean report looks like on screen.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
tok=$(LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 12)
temp=$((41 + RANDOM % 25)); fan=$((900 + RANDOM % 900)); fw="3.$((RANDOM % 9)).$((RANDOM % 90))"
disk=$(shuf -n 1 -e sda nvme0n1 vda); ups=$((20 + RANDOM % 70))
cat > vendor-diag <<DIAG
#!/bin/bash
# Acme vendor-diag 4.2: interactive diagnostics (needs a terminal)
if [ ! -t 1 ]; then
  echo "vendor-diag: not a terminal, aborting (run me interactively)" >&2
  exit 2
fi
printf '\033[1m== vendor-diag 4.2 ==\033[0m\n'
for f in '|' '/' '-' '\\' '|' '/' '-' '\\'; do
  printf '\rcollecting data %s' "\$f"
  sleep 0.1
done
printf '\r\033[K'
printf '\033[32mOK\033[0m   cpu temperature: $temp C\n'
printf '\033[32mOK\033[0m   disk $disk smart status: PASSED\n'
printf '\033[33mWARN\033[0m fan 2 speed: $fan rpm\n'
printf '\033[32mOK\033[0m   firmware: $fw\n'
printf '\033[32mOK\033[0m   ups battery: $ups%%\n'
printf 'session-token: $tok\n'
printf '\033[1m== end of report ==\033[0m\n'
DIAG
chmod +x vendor-diag
cat > .lm-state/expected.txt <<TXT
== vendor-diag 4.2 ==
OK   cpu temperature: $temp C
OK   disk $disk smart status: PASSED
WARN fan 2 speed: $fan rpm
OK   firmware: $fw
OK   ups battery: $ups%
session-token: $tok
== end of report ==
TXT
echo "$tok" > .lm-state/token
