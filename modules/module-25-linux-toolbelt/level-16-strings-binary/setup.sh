#!/bin/bash
# agent.bin: random bytes with embedded text.
#   ASCII:  a TEST block with fixture URLs, then "ENDPOINT" and the real URL.
#   UTF-16LE: a TEST block with a fixture licence, then the real licence.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
rnd() { head -c "$1" /dev/urandom; }
u16() { printf '%s' "$1" | iconv -f UTF-8 -t UTF-16LE; }
tok() { LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$1"; }
UP() { LC_ALL=C tr -dc 'A-Z0-9' < /dev/urandom | head -c "$1"; }
host="$(tok 6).$(tok 5)-cloud.example.net"
url="https://$host/v$((2 + RANDOM % 4))/beacon/$(tok 8)"
lic="AGT-$(UP 4)-$(UP 4)-$(UP 4)"
decoy_lic="AGT-$(UP 4)-$(UP 4)-$(UP 4)"
{
  rnd $((300 + RANDOM % 500))
  printf '\0TEST-BEGIN\0'
  printf '%s\0' "http://127.0.0.1:$((8000 + RANDOM % 900))/mock" "https://staging.$(tok 5).example.test/ping/$(tok 6)"
  printf 'TEST-END\0'
  rnd $((200 + RANDOM % 400))
  printf '\0LICENSE-FILE=/etc/agent/license.key\0'
  rnd $((100 + RANDOM % 300))
  printf '\0\0'; u16 'TEST-BEGIN'; printf '\0\0'
  u16 "LIC=$decoy_lic"; printf '\0\0'
  u16 'TEST-END'; printf '\0\0'
  rnd $((200 + RANDOM % 400))
  printf '\0ENDPOINT\0'
  printf '%s\0' "$url"
  rnd $((200 + RANDOM % 300))
  printf '\0\0'; u16 "LIC=$lic"; printf '\0\0'
  rnd $((300 + RANDOM % 500))
} > agent.bin
printf 'endpoint=%s\nlicense=%s\n' "$url" "$lic" > .lm-state/expected
echo "$decoy_lic" > .lm-state/decoy_lic
