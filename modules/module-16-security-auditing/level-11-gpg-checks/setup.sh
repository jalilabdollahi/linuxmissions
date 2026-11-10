#!/bin/bash
# Which Mirror Can You Trust. Four copies in mirrors/<name>/, roles shuffled per run:
#   good         vendor signature over this exact file
#   wrongkey     valid signature, but made by a third party's key (not in vendor.gpg)
#   tampered     modified tarball with the vendor's (old) valid signature for the original
#   wrongversion vendor signature, but for agent-2.3.0 (the file is 2.3.1)
# The four tarballs all differ in content, so the answer cannot be found by
# comparing hashes. Fixtures (keyring, tarballs, signatures) were generated once
# with throwaway demo keys and live in fixtures/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
FX="$(cd "$(dirname "$0")/fixtures" && pwd)"
rm -rf mirrors verified report.txt vendor.gpg .lm-state; mkdir -p mirrors verified .lm-state
cp "$FX/vendor.gpg" vendor.gpg

names=(mirror-eu mirror-us mirror-asia mirror-cdn)
roles=(good wrongkey tampered wrongversion)
order=$(printf '%s\n' 0 1 2 3 | awk -v s="$RANDOM" 'BEGIN{srand(s)} {print rand(), $0}' | sort -n | cut -d' ' -f2)
i=0
: > .lm-state/roles; : > .lm-state/hashes
for r in $order; do
  name=${names[$i]}; role=${roles[$r]}; i=$((i + 1))
  mkdir -p "mirrors/$name"
  cp "$FX/$role.tar.gz" "mirrors/$name/agent-2.3.1.tar.gz"
  case "$role" in
    good|tampered) sig=good.sig ;;
    wrongkey)      sig=wrongkey.sig ;;
    wrongversion)  sig=wrongversion.sig ;;
  esac
  cp "$FX/$sig" "mirrors/$name/agent-2.3.1.tar.gz.sig"
  printf '%s %s\n' "$name" "$role" >> .lm-state/roles
  printf '%s %s\n' "$(cksum < "$FX/$role.tar.gz" | tr ' ' :)" "$role" >> .lm-state/hashes
done
cksum < "$FX/vendor.gpg" > .lm-state/keyring-sum
