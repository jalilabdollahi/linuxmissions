#!/bin/bash
# docker-members.txt = docker's member list (field 4 of etc/group) plus every
# account whose primary GID (field 4 of etc/passwd) is docker's GID.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/passwd etc/group 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/passwd or etc/group was changed; they are copies from build-02, so type 'reset' to restore them"
  exit 1
fi
if [ ! -f docker-members.txt ]; then
  echo "❌ docker-members.txt does not exist yet"
  exit 1
fi

DGID=$(awk -F: '$1 == "docker" { print $3 }' etc/group)
LISTED=$(awk -F: '$1 == "docker" { n = split($4, m, ","); for (i = 1; i <= n; i++) if (m[i] != "") print m[i] }' etc/group)
PRIMARY=$(awk -F: -v g="$DGID" '$4 == g { print $1 }' etc/passwd)
WANT=$(printf '%s\n%s\n' "$LISTED" "$PRIMARY" | grep -v '^$' | LC_ALL=C sort -u)
GOT=$(tr -d '\r' < docker-members.txt | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort)

if [ "$GOT" = "$WANT" ]; then
  echo "✅ docker-members.txt has all $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') users who get the docker group, including those for whom it is the primary group"
  exit 0
fi
if [ -z "$GOT" ]; then
  echo "❌ docker-members.txt is empty"
  exit 1
fi
if [ -n "$(printf '%s\n' "$GOT" | uniq -d)" ]; then
  echo "❌ docker-members.txt names a user more than once"
  exit 1
fi
while IFS= read -r u; do
  printf '%s\n' "$WANT" | grep -qxF -- "$u" && continue
  if ! awk -F: -v u="$u" '$1 == u { f = 1 } END { exit !f }' etc/passwd; then
    echo "❌ '$u' is not a user on build-02; write one login name per line"
  elif awk -F: -v u="$u" '$1 == "docker-ci" { n = split($4, m, ","); for (i = 1; i <= n; i++) if (m[i] == u) f = 1 } END { exit !f }' etc/group; then
    echo "❌ $u is in docker-ci, a different group whose name only starts with docker"
  else
    echo "❌ $u is not in the docker group"
  fi
  exit 1
done <<< "$GOT"
if printf '%s\n' "$PRIMARY" | grep -qvxF -f <(printf '%s\n' "$GOT"); then
  echo "❌ someone is missing who never shows up in the group's member list: whose primary GID (passwd field 4) is docker's GID?"
  exit 1
fi
missing=$(printf '%s\n' "$WANT" | grep -cvxF -f <(printf '%s\n' "$GOT"))
echo "❌ $missing user(s) from the docker line's member list are missing"
exit 1
