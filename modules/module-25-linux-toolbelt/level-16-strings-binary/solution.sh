#!/bin/bash
# ASCII strings: drop the TEST block with a sed range, keep the line after ENDPOINT
url=$(strings -n 8 agent.bin | sed '/^TEST-BEGIN/,/^TEST-END/d' | grep -A1 '^ENDPOINT$' | tail -n 1)
# -e l = 16-bit little-endian text (UTF-16LE); same TEST block removal
lic=$(strings -n 8 -e l agent.bin | sed '/^TEST-BEGIN/,/^TEST-END/d' | grep '^LIC=' | cut -d= -f2)
printf 'endpoint=%s\nlicense=%s\n' "$url" "$lic" > findings.txt
cat findings.txt
