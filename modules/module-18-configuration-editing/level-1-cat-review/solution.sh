#!/bin/bash
# Show the invisible characters, then remove them in place.
cat -A app.conf
sed -i -e 's/\r$//' -e 's/\xc2\xa0/ /g' -e 's/[[:space:]]*$//' app.conf
cat -A app.conf
