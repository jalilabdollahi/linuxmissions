#!/bin/bash
# archive/ must hold exactly the three awkward files with their original
# content; every decoy must still be in uploads/, untouched.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

body() { printf 'portal upload: %s\nsize-class: %s\n' "$1" "$2"; }
same() { [ -f "$1" ] && [ "$(cat "$1")" = "$(body "$2" "$3")" ]; }

if [ ! -d archive ] || [ ! -d uploads ]; then
  echo "❌ archive/ or uploads/ is missing; type reset to start over"
  exit 1
fi

# Decoys first: hitting one is the typical quoting mistake.
for pair in 'Q3:D' 'report:E' '(final).pdf:F' 'price.csv:G' 'its done.txt:H' 'list.csv:I' 'Q3 report (draft).pdf:J'; do
  name="${pair%:*}"; tag="${pair##*:}"
  if [ -e "archive/$name" ]; then
    case "$name" in
      price.csv) echo "❌ archive/ got price.csv: inside double quotes \$list is expanded (to nothing), so \"price\$list.csv\" means price.csv" ;;
      'Q3 report (draft).pdf') echo "❌ archive/ got 'Q3 report (draft).pdf', which finance did not ask for" ;;
      *) echo "❌ archive/ got '$name': an unquoted name was split at its spaces" ;;
    esac
    exit 1
  fi
  if ! same "uploads/$name" "$name" "$tag"; then
    echo "❌ uploads/$name was removed or changed; type reset to start over"
    exit 1
  fi
done

for pair in 'Q3 report (final).pdf:A' 'price$list.csv:B' "it's done.txt:C"; do
  name="${pair%:*}"; tag="${pair##*:}"
  if [ -e "uploads/$name" ]; then
    echo "❌ '$name' is still in uploads/"
    exit 1
  fi
  if [ ! -e "archive/$name" ]; then
    echo "❌ '$name' is not in archive/ (check the exact name: ls -b archive)"
    exit 1
  fi
  if ! same "archive/$name" "$name" "$tag"; then
    echo "❌ archive/$name does not have its original content; move the file, don't recreate it"
    exit 1
  fi
done

extra="$(ls -A archive | grep -vxF -e 'Q3 report (final).pdf' -e 'price$list.csv' -e "it's done.txt")"
if [ -n "$extra" ]; then
  echo "❌ archive/ has something extra: $(printf '%s' "$extra" | head -1)"
  exit 1
fi
if [ "$(ls -A uploads | wc -l | tr -d ' ')" -ne 7 ]; then
  echo "❌ uploads/ should still hold its 7 other files and nothing else"
  exit 1
fi

echo "✅ the three files are archived and every look-alike stayed in uploads/"
exit 0
