#!/bin/bash
# NOTES.wrapped: same words, same paragraph/bullet structure, lines <= 72 and
# filled (no short line inside a paragraph).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
orig=.lm-state/notes.orig
if ! cmp -s NOTES.txt "$orig"; then echo "❌ NOTES.txt was changed; type 'reset' to restore it"; exit 1; fi
if [ ! -f NOTES.wrapped ]; then echo "❌ NOTES.wrapped does not exist yet"; exit 1; fi

canon() {  # one token per line: ¶ for a blank-line run, • for a bullet start, then the words
  awk '
    /^[[:space:]]*$/ { if (last != "¶") print "¶"; last = "¶"; next }
    { start = 1
      if ($1 == "-") { print "•"; start = 2 }
      for (i = start; i <= NF; i++) print $i
      last = "w" }
  ' "$1"
}
canon "$orig" > "$SANDBOX/.lm-state/c1"; canon NOTES.wrapped > "$SANDBOX/.lm-state/c2"
trap 'rm -f "$SANDBOX/.lm-state/c1" "$SANDBOX/.lm-state/c2"' EXIT
if ! cmp -s "$SANDBOX/.lm-state/c1" "$SANDBOX/.lm-state/c2"; then
  p1=$(grep -c '^¶$' "$SANDBOX/.lm-state/c1"); p2=$(grep -c '^¶$' "$SANDBOX/.lm-state/c2")
  b1=$(grep -c '^•$' "$SANDBOX/.lm-state/c1"); b2=$(grep -c '^•$' "$SANDBOX/.lm-state/c2")
  if [ "$b1" -ne "$b2" ]; then echo "❌ NOTES.wrapped has $b2 bullet items, NOTES.txt has $b1: bullets were merged or split"
  elif [ "$p1" -ne "$p2" ]; then echo "❌ NOTES.wrapped has $p2 paragraph breaks, NOTES.txt has $p1: paragraphs were merged or split"
  else echo "❌ the words of NOTES.wrapped differ from NOTES.txt (text lost, added or reordered)"; fi
  exit 1
fi
long=$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' NOTES.wrapped)
if [ "$long" -gt 72 ]; then echo "❌ the longest line of NOTES.wrapped is $long characters, the limit is 72"; exit 1; fi
short=$(awk '
  { L[NR] = $0 }
  END { for (i = 1; i < NR; i++)
          if (L[i] !~ /^[[:space:]]*$/ && L[i + 1] !~ /^[[:space:]]*$/ && L[i + 1] !~ /^[[:space:]]*- / && length(L[i]) < 45) { print i; exit } }' NOTES.wrapped)
if [ -n "$short" ]; then echo "❌ line $short of NOTES.wrapped is short but the paragraph continues on the next line: the text is not reflowed yet"; exit 1; fi
if [ "$(grep -c '^  - ' NOTES.wrapped)" -ne "$(grep -c '^  - ' "$orig")" ]; then
  echo "❌ every bullet must still start on its own line with '  - ' (two spaces of indentation, as in NOTES.txt)"; exit 1
fi
if grep -qE '^ {0,1}[^ -]|^ {3,}[^ ]' <(sed -n '/^  - /,/^$/p' NOTES.wrapped); then
  echo "❌ the lines inside a bullet lost the 2-space indentation of the list"; exit 1
fi
echo "✅ NOTES.wrapped: $(wc -l < NOTES.wrapped | tr -d ' ') lines of at most 72 characters, paragraphs and bullets intact"
exit 0
