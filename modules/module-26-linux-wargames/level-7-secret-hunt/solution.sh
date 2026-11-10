#!/bin/bash
KEY=$(grep -o 'pk_live_[A-Za-z0-9]*' TICKET.md | head -1)
B64=$(printf %s "$KEY" | base64 -w0)
: > leaks.txt
# plain-text copies (hidden files too)
grep -rIlF "$KEY" site >> leaks.txt
# base64 copies
grep -rIlF "$B64" site >> leaks.txt
# copies broken across a continued line
grep -rIlE 'pk_live_[A-Za-z0-9]*\\$' site >> leaks.txt
# inside gzip files and tarballs
for f in $(find site -name '*.gz' ! -name '*.tgz'); do zgrep -qF "$KEY" "$f" && echo "$f" >> leaks.txt; done
for a in $(find site -name '*.tgz'); do
  for m in $(tar -tzf "$a"); do tar -xzOf "$a" "$m" | grep -qF "$KEY" && echo "$a:$m" >> leaks.txt; done
done
sort -u -o leaks.txt leaks.txt
# redact in place
grep -rIlF "$KEY" site | xargs sed -i "s/$KEY/REDACTED/g"
grep -rIlF "$B64" site | xargs sed -i "s/$B64/UkVEQUNURUQ=/g"
for f in $(grep -rIlE 'pk_live_[A-Za-z0-9]*\\$' site); do
  sed -i -z 's/pk_live_[A-Za-z0-9]*\\\n[A-Za-z0-9]*/REDACTED/' "$f"
done
cat leaks.txt
