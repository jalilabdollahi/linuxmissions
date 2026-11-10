#!/bin/bash
# Parse my.cnf (duplicate sections merge, last value wins) and compare with the
# original: exactly one changed line and one added line, both in the first [mysqld].
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f my.cnf ]; then
  echo "❌ my.cnf is missing"
  exit 1
fi
if cmp -s my.cnf .lm-state/original.cnf; then
  echo "❌ my.cnf has not been changed yet"
  exit 1
fi

# Effective config: one "section key value" line per setting, last definition wins.
effective() {
  awk '
    /^[[:space:]]*[#;]/ || /^[[:space:]]*$/ { next }
    /^[[:space:]]*\[.*\][[:space:]]*$/ { gsub(/[[:space:]]/, ""); sec = $0; next }
    {
      line = $0; key = line; val = ""
      if (index(line, "=")) { key = substr(line, 1, index(line, "=") - 1); val = substr(line, index(line, "=") + 1) }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key); gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      v[sec "\t" key] = val
      if (!((sec "\t" key) in seen)) { seen[sec "\t" key] = 1; order[++n] = sec "\t" key }
    }
    END { for (i = 1; i <= n; i++) print order[i] "\t" v[order[i]] }
  ' "$1" | LC_ALL=C sort
}
eff=$(effective my.cnf)
get() { printf '%s\n' "$eff" | awk -F'\t' -v s="$1" -v k="$2" '$1 == s && $2 == k { print $3 }'; }

if [ "$(get '[mysqld]' max_connections)" != "500" ]; then
  echo "❌ the effective max_connections of [mysqld] is '$(get '[mysqld]' max_connections)', expected 500"
  exit 1
fi
if [ "$(get '[mysqld]' innodb_buffer_pool_size)" != "2G" ]; then
  echo "❌ the effective innodb_buffer_pool_size of [mysqld] is '$(get '[mysqld]' innodb_buffer_pool_size)', expected 2G"
  exit 1
fi
if [ "$(get '[client]' max_allowed_packet)" != 16M ] || [ "$(get '[mysqldump]' max_allowed_packet)" != 128M ] || [ "$(get '[mysqld]' max_allowed_packet)" != 64M ]; then
  echo "❌ a max_allowed_packet value was changed: [client], [mysqld] and [mysqldump] each keep their own"
  exit 1
fi
if [ "$(grep -c '^[[:space:]]*max_connections[[:space:]]*=' my.cnf)" != 1 ] || [ "$(grep -c '^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=' my.cnf)" != 1 ]; then
  echo "❌ max_connections and innodb_buffer_pool_size must each be defined exactly once"
  exit 1
fi

# The new setting belongs to the first [mysqld] block.
inblk=$(awk '/^\[/ { n += ($0 == "[mysqld]"); cur = $0 } n == 1 && cur == "[mysqld]" && /^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=/ { f = 1 } END { print f + 0 }' my.cnf)
if [ "$inblk" != 1 ]; then
  echo "❌ innodb_buffer_pool_size is not in the first [mysqld] block: add it there, next to the other server settings"
  exit 1
fi

# Everything else must be as before: remove the two touched lines from both files and compare.
norm() { grep -v -e '^[[:space:]]*max_connections[[:space:]]*=' -e '^[[:space:]]*innodb_buffer_pool_size[[:space:]]*=' "$1"; }
if ! diff <(norm .lm-state/original.cnf | grep -v '^# max_connections') <(norm my.cnf | grep -v '^# max_connections') >/dev/null \
   || [ "$(grep -c '^# max_connections = 1000' my.cnf)" != 1 ]; then
  n=$(diff <(norm .lm-state/original.cnf) <(norm my.cnf) | grep -c '^[<>]')
  echo "❌ other lines of my.cnf changed ($n differing line(s)): comments, other settings and the second [mysqld] block must stay as they were"
  exit 1
fi
echo "✅ max_connections is 500 and innodb_buffer_pool_size is 2G in the first [mysqld]; nothing else moved"
exit 0
