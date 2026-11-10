#!/bin/bash
# types.tsv: one `file<TAB>class` line per file in quarantine/, exact classes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
[ -s .lm-state/expected ] && [ -d quarantine ] || { echo "❌ the capture is gone; type 'reset'"; exit 1; }
[ -f types.tsv ] || { echo "❌ types.tsv does not exist yet"; exit 1; }
got=$(tr -d '\r' < types.tsv | grep -v '^[[:space:]]*$' | LC_ALL=C sort)
want=$(LC_ALL=C sort .lm-state/expected)
[ -n "$got" ] || { echo "❌ types.tsv is empty"; exit 1; }
if [ "$got" = "$want" ]; then
  echo "✅ all $(wc -l <<< "$want" | tr -d ' ') files classified correctly"; exit 0
fi
if grep -qv "$(printf '\t')" <<< "$got"; then
  echo "❌ every line needs a TAB between the file name and the class"; exit 1
fi
if grep -qvE "	(elf|script|image|text|archive:(elf|script|image|text))\$" <<< "$got"; then
  bad=$(grep -vE "	(elf|script|image|text|archive:(elf|script|image|text))\$" <<< "$got" | head -1 | cut -f2)
  echo "❌ '$bad' is not one of elf, script, image, text, archive:<class>"; exit 1
fi
ng=$(wc -l <<< "$got" | tr -d ' ')
if [ "$(cut -f1 <<< "$got" | sort -u | wc -l | tr -d ' ')" -ne "$ng" ]; then echo "❌ a file is listed twice"; exit 1; fi
if [ "$ng" -ne "$(wc -l <<< "$want" | tr -d ' ')" ]; then
  echo "❌ types.tsv has $ng lines, quarantine/ holds $(wc -l <<< "$want" | tr -d ' ') files (names with spaces count too)"; exit 1
fi
line=$(diff <(echo "$want") <(echo "$got") | grep '^>' | head -1 | sed 's/^> //')
name=$(cut -f1 <<< "$line")
if [ ! -e "quarantine/$name" ]; then echo "❌ '$name' is not a file in quarantine/ (give the name without the directory)"; exit 1; fi
c=$(cut -f2 <<< "$line"); w=$(grep -F "$name	" <<< "$want" | head -1 | cut -f2)
case "$w" in
  archive:*) [ "${c#archive:}" = "$c" ] && echo "❌ '$name' is compressed: the class must be archive:<what is inside>" || echo "❌ '$name' is an archive, but its inner class is wrong (decompress and look at the content)" ;;
  *) echo "❌ '$name' is classified wrongly: the extension is not evidence, look at the content" ;;
esac
exit 1
