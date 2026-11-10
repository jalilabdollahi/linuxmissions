#!/bin/bash
# The five changes as one sed script. Line numbers in a sed script refer to the input file,
# so the deletions further down cannot shift the 120,180 range.
sed -i \
  -e '/^# LEGACY/,/^# END LEGACY/{/^acl /d}' \
  -e '120,180s/^http_port 3128/http_port 3129/' \
  -e '/^# ---- local overrides below ----/r snippet.conf' \
  squid.conf
sed -i '/^cache_dir /{N;s/\n[[:space:]]*/ /}' squid.conf
diff .lm-state/original.conf squid.conf | head -30
