#!/bin/bash
# 1. etc/skel holds exactly the paths and modes of skel-spec.txt, and the three
#    dotfiles equal the package's. 2. dana exists (created through the mock, so she
#    is in passwd) and home/dana is a faithful copy of the fixed skel (same names,
#    modes, contents). 3. alice's home is unchanged.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum skel-spec.txt usr/share/base-files/dot.* 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ skel-spec.txt or usr/share/base-files was changed; they are the reference, so type 'reset' to get them back"
  exit 1
fi

# 1. the skeleton against the spec
SPEC=$(grep -v '^[[:space:]]*#' skel-spec.txt | grep -v '^[[:space:]]*$' | awk '{ p = $2; sub("/$", "", p); print $1, p }' | LC_ALL=C sort -k2)
HAVE=$(cd etc/skel && find . -mindepth 1 | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do printf '%s %s\n' "$(stat -c %a "$f")" "$f"; done | LC_ALL=C sort -k2)
specpaths=$(printf '%s\n' "$SPEC" | awk '{ print $2 }')
havepaths=$(printf '%s\n' "$HAVE" | awk '{ print $2 }')
extra=$(comm -13 <(printf '%s\n' "$specpaths") <(printf '%s\n' "$havepaths") | head -n 1)
if [ -n "$extra" ]; then
  echo "❌ etc/skel contains $extra, which is not in skel-spec.txt (hidden files do not show in a plain ls)"
  exit 1
fi
absent=$(comm -23 <(printf '%s\n' "$specpaths") <(printf '%s\n' "$havepaths") | head -n 1)
if [ -n "$absent" ]; then
  echo "❌ etc/skel has no $absent, but skel-spec.txt lists it"
  exit 1
fi
while read -r mode path; do
  got=$(printf '%s\n' "$HAVE" | awk -v p="$path" '$2 == p { print $1 }')
  if [ "$got" != "$mode" ]; then
    echo "❌ etc/skel/$path is mode $got, the spec says $mode"
    exit 1
  fi
done <<< "$SPEC"
for f in profile bashrc bash_logout; do
  if ! cmp -s "etc/skel/.$f" "usr/share/base-files/dot.$f"; then
    echo "❌ etc/skel/.$f is not the package's dot.$f (see usr/share/base-files/)"
    exit 1
  fi
done

# 2. dana
if ! grep -q '^dana:' etc/passwd 2>/dev/null; then
  echo "❌ the skeleton is right, but dana does not exist yet: create her with bin/useradd -m"
  exit 1
fi
if [ "$(awk -F: '$1 == "dana" { print $6 }' etc/passwd)" != /home/dana ] || [ ! -d home/dana ]; then
  echo "❌ dana's home /home/dana is not in home/: create it with the mock bin/useradd -m"
  exit 1
fi
snapdir() { (cd "$1" && find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r f; do
  if [ -f "$f" ]; then printf '%s %s %s\n' "$(stat -c %a "$f")" "$f" "$(cksum < "$f")"; else printf '%s %s\n' "$(stat -c %a "$f")" "$f"; fi
done); }
S=$(snapdir etc/skel); D=$(snapdir home/dana)
if [ "$S" != "$D" ]; then
  miss=$(comm -23 <(printf '%s\n' "$S" | awk '{ print $2 }') <(printf '%s\n' "$D" | awk '{ print $2 }') | head -n 1)
  if [ -n "$miss" ]; then
    echo "❌ home/dana has no ${miss#./}: her home is not a copy of the fixed skeleton"
  else
    echo "❌ home/dana differs from the fixed etc/skel (a file or mode is not as in the skeleton): skel is copied only when the account is created, so was dana created before the fix?"
  fi
  exit 1
fi

# 3. alice
if [ "$(snapdir home/alice)" != "$(sed '/^[0-9]* \.$/d' .lm-state/alice)" ]; then
  echo "❌ alice's home changed: skel only matters for new accounts, her existing files must stay as they are"
  exit 1
fi
echo "✅ etc/skel matches the spec and dana's new home is an exact copy of it; alice is untouched"
exit 0
