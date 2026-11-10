#!/bin/bash
SANDBOX="$1"
FILE="$SANDBOX/sudoers.d/deploy"

if [ ! -f "$FILE" ]; then
  echo "❌ sudoers.d/deploy does not exist yet"
  exit 1
fi

# 1. Syntax, checked by the real parser when it is installed.
if command -v visudo >/dev/null 2>&1 || [ -x /usr/sbin/visudo ]; then
  VISUDO="$(command -v visudo || echo /usr/sbin/visudo)"
  if ! "$VISUDO" -cf "$FILE" >/dev/null 2>&1; then
    echo "❌ visudo -cf sudoers.d/deploy reports a syntax error; run it to see where"
    exit 1
  fi
fi

# 2. Permissions: sudo wants drop-in files read-only, 0440.
if [ "$(ls -l "$FILE" | cut -c1-10)" != "-r--r-----" ]; then
  echo "❌ sudoers.d/deploy has mode $(ls -l "$FILE" | cut -c1-10); sudoers files should be 0440 (-r--r-----)"
  exit 1
fi

# 3. Meaning: list every command the file grants, as "user|runas|tag|command".
GRANTS="$(sed -e ':a' -e '/\\$/N; s/\\\n/ /; ta' "$FILE" | awk '
  function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
  /^[[:space:]]*(#|@)include/ { next }
  { sub(/#.*/, "") }
  NF == 0 { next }
  $1 == "Defaults" || $1 ~ /^Defaults[:@>!]/ { print "DEFAULTS|" $0; next }
  $1 == "Cmnd_Alias" {
    line = $0; sub(/^[[:space:]]*Cmnd_Alias[[:space:]]+/, "", line)
    name = trim(substr(line, 1, index(line, "=") - 1)); alias[name] = trim(substr(line, index(line, "=") + 1)); next
  }
  $1 ~ /_Alias$/ { print "OTHERALIAS|" $1; next }
  {
    user = $1
    rest = $0; sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+/, "", rest)
    host = trim(substr(rest, 1, index(rest, "=") - 1))
    spec = trim(substr(rest, index(rest, "=") + 1))
    if (host != "ALL") { print "HOST|" user "|" host; next }
    runas = "root"; tag = "PASSWD"
    n = split(spec, items, ",")
    for (i = 1; i <= n; i++) {
      c = trim(items[i])
      if (c ~ /^\(/) { runas = substr(c, 2, index(c, ")") - 2); c = trim(substr(c, index(c, ")") + 1)) }
      while (match(c, /^[A-Z_]+:/)) {
        t = substr(c, 1, RLENGTH - 1)
        if (t == "NOPASSWD" || t == "PASSWD") tag = t
        c = trim(substr(c, RLENGTH + 1))
      }
      if (c in alias) {
        m = split(alias[c], ac, ",")
        for (j = 1; j <= m; j++) { x = trim(ac[j]); gsub(/[[:space:]]+/, " ", x); print user "|" runas "|" tag "|" x }
      } else { gsub(/[[:space:]]+/, " ", c); print user "|" runas "|" tag "|" c }
    }
  }')"

if printf '%s\n' "$GRANTS" | grep -q '^DEFAULTS|'; then
  echo "❌ leave Defaults out of this file; per-command NOPASSWD: is all that is needed"
  exit 1
fi
if printf '%s\n' "$GRANTS" | grep -q '^OTHERALIAS|\|^HOST|'; then
  echo "❌ keep it simple: host must be ALL and only Cmnd_Alias is supported here"
  exit 1
fi
if [ -z "$GRANTS" ]; then
  echo "❌ sudoers.d/deploy contains no rule yet"
  exit 1
fi
if printf '%s\n' "$GRANTS" | grep -vq '^deploy|'; then
  echo "❌ this file should only contain rules for the user deploy"
  exit 1
fi
if printf '%s\n' "$GRANTS" | cut -d'|' -f2 | grep -Evqx 'root|ALL|root:root|ALL:ALL|root:ALL|ALL:root'; then
  echo "❌ the commands must run as root (runas should be (root) or (ALL))"
  exit 1
fi
if printf '%s\n' "$GRANTS" | grep -q '|PASSWD|'; then
  echo "❌ at least one command would still ask deploy for a password (NOPASSWD: missing)"
  exit 1
fi

CMDS="$(printf '%s\n' "$GRANTS" | cut -d'|' -f4 | sort -u)"
if printf '%s\n' "$CMDS" | grep -Eq '^ALL$|\*|^[^/]'; then
  echo "❌ the rule is too broad or uses a relative path: list exact absolute commands, no ALL and no wildcards"
  exit 1
fi
if printf '%s\n' "$CMDS" | grep -qx '/usr/bin/systemctl'; then
  echo "❌ a bare /usr/bin/systemctl allows ANY systemctl subcommand (stop sshd, edit units...); add the arguments"
  exit 1
fi
WANT='/usr/bin/systemctl restart myapp.service
/usr/bin/systemctl status myapp.service'
for w in "/usr/bin/systemctl restart myapp.service" "/usr/bin/systemctl status myapp.service"; do
  if ! printf '%s\n' "$CMDS" | grep -Fxq "$w"; then
    echo "❌ deploy.sh would still be refused for one of its sudo commands (compare the arguments exactly)"
    exit 1
  fi
done
if [ "$CMDS" != "$(printf '%s\n' "$WANT" | sort)" ]; then
  echo "❌ the file grants more commands than deploy.sh needs"
  exit 1
fi

echo "✅ deploy may run exactly the two systemctl commands as root without a password"
exit 0
