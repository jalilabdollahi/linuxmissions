#!/bin/bash
# Two substitutions with -E, # as the delimiter for the URL, escaped dots,
# g for several matches per line; find reaches templates/emails/ as well.
grep -rn 'old-cdn' templates | head -5
find templates -name '*.html' -exec sed -i -E \
  -e 's#http://old-cdn\.example\.com/#https://cdn.example.net/v2/#g' \
  -e 's#([0-9]{2})/([0-9]{2})/([0-9]{4})#\3-\2-\1#g' {} +
grep -rn 'cdn\.\|Published' templates/index.html
