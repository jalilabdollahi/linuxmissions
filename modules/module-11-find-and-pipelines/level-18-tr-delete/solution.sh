#!/bin/bash
# Look at the bytes, strip the colour sequences while the ESC is still there,
# then delete CR, NUL and BEL.
od -c console.raw | head -12
sed $'s/\e\\[[0-9;]*m//g' console.raw | tr -d '\r\000\007' > console.txt
cat -A console.txt | head -30
