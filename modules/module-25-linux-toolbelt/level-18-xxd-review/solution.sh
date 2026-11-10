#!/bin/bash
# 1. one byte per line, in plain hex
xxd -p -c1 config.bin > bytes.txt
# 2. line 43 is offset 0x2A (lines count from 1, offsets from 0)
sed -i '43s/.*/01/' bytes.txt
# 3. add up the first 127 bytes (0x prefix makes bash read them as hex)
sum=0
for b in $(head -n 127 bytes.txt); do sum=$((sum + 0x$b)); done
# 4. new last byte = sum mod 256, then turn the hex dump back into binary
{ head -n 127 bytes.txt; printf '%02x\n' $((sum % 256)); } | xxd -r -p > config.new
mv config.new config.bin
xxd config.bin | head -4
