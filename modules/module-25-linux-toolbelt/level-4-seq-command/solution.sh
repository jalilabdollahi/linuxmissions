#!/bin/bash
# seq FIRST STEP LAST with a printf-style format that pads to two digits.
read -r letter first last < <(awk '/^rack:/{l=$2} /^first/{f=$3} /^last/{e=$3} END{print l, f, e}' label-request.txt)
seq -f "rack-$letter-%02g" "$first" 2 "$last" > labels.txt
head -3 labels.txt
