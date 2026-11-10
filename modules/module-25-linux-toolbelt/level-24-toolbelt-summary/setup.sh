#!/bin/bash
# bundle.eml: multipart/mixed with three base64 parts in random order:
#   text    - Content-Type text/plain, utf-8: a note with a recommended setting (and an old one)
#   log     - application/octet-stream: a UTF-16 (with BOM) service log
#   dmesg   - labelled text/plain, but it is gzip data
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
tok() { LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"; }
kern="$(shuf -n 1 -e 5.15.0 6.1.0 6.5.0 6.8.0)-$((20 + RANDOM % 120))-generic"
workers=$((8 + RANDOM % 120)); oldworkers=$((2 + RANDOM % 6))
key=$(shuf -n 1 -e max_workers pool_size queue_depth)
errors=$((9 + RANDOM % 30))
# service log
awk -v e="$errors" -v s="$RANDOM$$" 'BEGIN {
  srand(s); total = e + 40 + int(rand() * 40)
  for (i = 0; i < total; i++) isErr[i] = 0
  c = 0; while (c < e) { k = int(rand() * total); if (!isErr[k]) { isErr[k] = 1; c++ } }
  split("connection reset by peer|disk quota exceeded|upstream timeout|queue overflow|certificate expired", em, "|")
  for (i = 0; i < total; i++) {
    t = sprintf("2026-11-09 %02d:%02d:%02d", int(i * 24 / total), int(rand() * 60), int(rand() * 60))
    if (isErr[i]) printf "%s ERROR worker-%d %s\n", t, int(rand() * 8), em[1 + int(rand() * 5)]
    else if (rand() < 0.25) printf "%s WARN worker-%d transient error, retrying (attempt %d)\n", t, int(rand() * 8), 1 + int(rand() * 3)
    else printf "%s INFO worker-%d request handled in %dms\n", t, int(rand() * 8), 5 + int(rand() * 400)
  }
}' | iconv -f UTF-8 -t UTF-16 > .lm-state/service.log.u16
# kernel log (gzip)
{
  echo "[    0.000000] Linux version $kern (buildd@lcy02-amd64-$((RANDOM % 90))) (gcc 13.2.0) #$((RANDOM % 90))-Ubuntu SMP"
  echo "[    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz root=UUID=$(tok 8) ro quiet"
  for i in $(seq 1 $((30 + RANDOM % 20))); do
    printf '[%12.6f] %s\n' "$(awk -v i=$i 'BEGIN{print 0.1 * i * i / 10}')" "$(shuf -n 1 -e 'ACPI: PM-Timer IO Port: 0x608' 'Memory: 8123456K available' 'NET: Registered PF_INET protocol family' 'EXT4-fs (sda1): mounted filesystem' 'usb 1-1: new high-speed USB device' 'systemd[1]: Started Journal Service.' 'random: crng init done')"
  done
} | gzip -9n > .lm-state/dmesg.gz
# text part
cat > .lm-state/note.txt <<TXT
Hi team,

the box crashed twice last night. I think it runs kernel 5.4.0 but please
check the attached boot log rather than my memory.

Old setting: $key=$oldworkers
Recommended setting: $key=$workers

Thanks,
Dana (support)
TXT
b="----=_Part_$(tok 16)"
mk() {  # mk <ctype-header-line> <file>
  printf -- '--%s\n%s\nContent-Transfer-Encoding: base64\n\n' "$b" "$1"
  base64 "$2"
  echo
}
order=($(shuf -e text log dmesg))
{
  printf 'From: support@vendor.example\nTo: ops@corp.example\nSubject: Crash bundle %s\nMIME-Version: 1.0\n' "$(tok 6)"
  printf 'Content-Type: multipart/mixed; boundary="%s"\n\nThis is a multi-part message in MIME format.\n\n' "$b"
  for p in "${order[@]}"; do
    case $p in
      text)  mk 'Content-Type: text/plain; charset=utf-8' .lm-state/note.txt ;;
      log)   mk 'Content-Type: application/octet-stream; name="service.log"
Content-Disposition: attachment; filename="service.log"' .lm-state/service.log.u16 ;;
      dmesg) mk 'Content-Type: text/plain; name="dmesg.txt"
Content-Disposition: attachment; filename="dmesg.txt"' .lm-state/dmesg.gz ;;
    esac
  done
  printf -- '--%s--\n' "$b"
} > bundle.eml
printf 'errors: %s\nkernel: %s\nsetting: %s=%s\n' "$errors" "$kern" "$key" "$workers" > .lm-state/expected
