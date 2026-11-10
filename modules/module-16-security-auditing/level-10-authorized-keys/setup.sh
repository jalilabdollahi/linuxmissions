#!/bin/bash
# Offboarding Day. authorized_keys with ten throwaway ed25519 keys (new ones on
# every run, shuffled). Leavers: bob, mallory, trent. Comments lie: the key
# commented alice@laptop is bob's (leaver), and the key commented bob@desktop
# is alice's (stays). One staying key already has an option (no-agent-forwarding)
# that must survive. The CI key is bare.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf authorized_keys* offboard.txt .lm-state; mkdir -p .lm-state/tmp
T=.lm-state/tmp
gen() { rm -f "$T/k" "$T/k.pub"; ssh-keygen -q -t ed25519 -N '' -C x -f "$T/k" >/dev/null 2>&1 || exit 1; awk '{print $1, $2}' "$T/k.pub"; }

# "who|comment shown in file|leaver(1/0)|extra"
entries=(
  "bob|alice@laptop|1|"
  "alice|bob@desktop|0|"
  "mallory|mallory@old-laptop|1|"
  "trent|trent@build-box|1|"
  "carol|carol@workstation|0|"
  "dave|dave@desktop|0|"
  "erin|erin@laptop|0|no-agent-forwarding"
  "frank|frank@home|0|"
  "ci|ci-deploy@runner|0|"
  "heidi|heidi@tablet|0|"
)
: > .lm-state/lines; : > .lm-state/leavers; : > .lm-state/stay
for e in "${entries[@]}"; do
  IFS='|' read -r who comment leaver extra <<< "$e"
  key=$(gen)
  line="$key $comment"; [ -n "$extra" ] && line="$extra $line"
  printf '%s\t%s\t%s\n' "$who" "$leaver" "$line" >> .lm-state/lines
done
shuf_lines=$(awk -v seed="$RANDOM" 'BEGIN{srand(seed)} {print rand() "\t" $0}' .lm-state/lines | sort -n | cut -f2-)
{
  echo "# authorized_keys for deploy@build-01 (managed by hand, sorry)"
  printf '%s\n' "$shuf_lines" | cut -f3
  echo
} > authorized_keys
# fingerprints of the leavers
: > offboard.txt
{
  echo "# Offboarding 2026-10-30: remove these keys from every host"
  while IFS=$'\t' read -r who leaver line; do
    [ "$leaver" = 1 ] || continue
    fp=$(printf '%s\n' "$line" | ssh-keygen -lf - | awk '{print $2}')
    printf '%s  %s\n' "$fp" "$who"
    echo "$fp" >> .lm-state/leavers
  done < .lm-state/lines
} > offboard.txt
# per staying key: original line and blob
while IFS=$'\t' read -r who leaver line; do
  [ "$leaver" = 0 ] || continue
  printf '%s\t%s\t%s\n' "$who" "$(printf '%s\n' "$line" | ssh-keygen -lf - | awk '{print $2}')" "$line" >> .lm-state/stay
done < .lm-state/lines
rm -rf "$T"
