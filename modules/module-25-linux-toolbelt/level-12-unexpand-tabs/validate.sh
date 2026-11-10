#!/bin/bash
# Makefile = original with the leading 8 spaces of each recipe line (state
# machine: after a "target:" line, until a non-indented/blank/other line)
# replaced by one tab; every other line byte for byte.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
orig=.lm-state/Makefile.orig
if [ ! -s Makefile ]; then echo "❌ Makefile is missing or empty; restore it from Makefile.orig"; exit 1; fi

expect=$(mktemp "$SANDBOX/.lm-state/expect.XXXXXX"); trap 'rm -f "$expect"' EXIT
awk '
{
  line = $0
  if (line ~ /^        [^ ]/ && inrecipe) { print "\t" substr(line, 9); next }
  print line
  if (line ~ /^[ \t]*$/) { inrecipe = 0; next }
  if (line ~ /^[^ \t#]/) {
    ci = index(line, ":"); ei = index(line, "=")
    inrecipe = (ci > 0 && (ei == 0 || ci < ei) && substr(line, ci + 1, 1) != "=" && line !~ /^\./)
    # a variable whose line ends in a backslash keeps its continuation lines non-recipe
    next
  }
}' "$orig" > "$expect"

if cmp -s Makefile "$expect"; then
  echo "✅ Makefile: $(grep -c "$(printf '^\t')" "$expect") recipe lines start with a tab, everything else untouched"
  exit 0
fi
if [ "$(wc -l < Makefile)" -ne "$(wc -l < "$expect")" ]; then
  echo "❌ Makefile has $(wc -l < Makefile) lines, expected $(wc -l < "$expect")"; exit 1
fi
bad=$(diff Makefile "$expect" | grep -m1 '^[0-9]' | sed 's/[^0-9].*//')
got=$(sed -n "${bad}p" Makefile); want=$(sed -n "${bad}p" "$expect")
case "$want" in
  "$(printf '\t')"*) echo "❌ line $bad is a recipe line but does not start with a tab: '${got}'" ;;
  *) if [ "${got#"$(printf '\t')"}" != "$got" ]; then
       echo "❌ line $bad starts with a tab but is not a recipe line (a variable continuation or a comment): '$(printf '%s' "$got" | sed 's/\t/<TAB>/')'"
     else echo "❌ line $bad differs from the original: '$got'"; fi ;;
esac
exit 1
