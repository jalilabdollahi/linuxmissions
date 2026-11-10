#!/bin/bash
# -j 8 skips the file header, -w16 puts one 16-byte record on each output row,
# -v keeps repeated rows, -A n drops the offset column. Three -t formats
# print each record three times (as u32, as u16, as float); paste joins them.
od -A n -v -j 8 -w16 --endian=little -t u4 -t u2 -t f4 sensors.bin | paste - - - > records.txt
head -n 3 records.txt
# u32 fields are $1..$4, u16 fields $5..$12, float fields $13..$16:
# timestamp = $1, sensor = $7, status = $8, value = $15
awk '$8 != 0 { print $1, $7, $15 }' records.txt > faults.txt
cat faults.txt
