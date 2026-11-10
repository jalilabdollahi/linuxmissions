#!/bin/bash
# Read the request, make an image of exactly that size, then build the file
# system with the label, reserve percentage and inode ratio from the request.
cat REQUEST.txt
size=$(grep -o 'exactly [0-9]*' REQUEST.txt | grep -o '[0-9]*')
label=$(grep -o 'label: *[A-Z]*' REQUEST.txt | grep -o '[A-Z]*$')
pct=$(grep -o 'reserved: *[0-9]*' REQUEST.txt | grep -o '[0-9]*$')
ratio=$(grep -o 'every [0-9]* bytes' REQUEST.txt | grep -o '[0-9]*')
truncate -s ${size}M logs.img
mke2fs -q -F -t ext4 -L "$label" -m "$pct" -i "$ratio" logs.img
dumpe2fs -h logs.img 2>/dev/null | grep -E 'volume name|Block count|Reserved block count|Inode count'
