#!/bin/bash
# relogin.txt = users whose session (sessions/<user>.status, Groups:) is missing a
# GID that etc/group / etc/passwd give them today. An extra GID in the session is
# not "missing" and does not put the user on the list.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/passwd etc/group sessions/*.status 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/passwd, etc/group or a sessions/*.status file was changed; they are the evidence, so type 'reset' to get them back"
  exit 1
fi
if [ ! -f relogin.txt ]; then
  echo "❌ relogin.txt does not exist yet"
  exit 1
fi

# db_gids USER: primary GID plus every group listing USER as a member
db_gids() {
  awk -F: -v u="$1" 'NR == FNR { if ($1 == u) p = $4; next }
    { n = split($4, m, ","); for (i = 1; i <= n; i++) if (m[i] == u) g[$3] = 1 }
    END { g[p] = 1; for (k in g) print k }' etc/passwd etc/group | sort
}
sess_gids() { awk '$1 == "Groups:" { for (i = 2; i <= NF; i++) print $i }' "sessions/$1.status" | sort; }

WANT=""
for f in sessions/*.status; do
  u=${f#sessions/}; u=${u%.status}
  if [ -n "$(comm -23 <(db_gids "$u") <(sess_gids "$u"))" ]; then WANT="$WANT$u
"; fi
done
WANT=$(printf '%s' "$WANT" | LC_ALL=C sort)
GOT=$(tr -d '\r' < relogin.txt | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | LC_ALL=C sort)

[ "$GOT" = "$WANT" ] && {
  echo "✅ relogin.txt names the $(printf '%s\n' "$WANT" | wc -l | tr -d ' ') users whose sessions predate a group change"
  exit 0
}
if [ -z "$GOT" ]; then
  echo "❌ relogin.txt is empty"
  exit 1
fi
while IFS= read -r u; do
  printf '%s\n' "$WANT" | grep -qxF -- "$u" && continue
  if [ ! -f "sessions/$u.status" ]; then
    echo "❌ '$u' has no session capture; list login names, one per line"
  elif [ -n "$(comm -13 <(db_gids "$u") <(sess_gids "$u"))" ]; then
    echo "❌ $u's session holds a group that etc/group no longer gives them, but it lacks none: that is not a missing group, so no re-login is needed for this ticket"
  else
    echo "❌ $u's session already holds every group etc/group gives them"
  fi
  exit 1
done <<< "$GOT"
echo "❌ a user whose session lacks a group they have in etc/group is missing from relogin.txt"
exit 1
