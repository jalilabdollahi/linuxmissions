#!/bin/bash
# The unit name is on the "See 'systemctl status X'" line after each failure.
grep -n 'FAILED' sysroot/var/log/boot.log | cat -v | head -3
sed 's/\x1b\[[0-9;]*m//g' sysroot/var/log/boot.log | sed -n "s/^ *See 'systemctl status \(.*\)' for details\./\1/p" | awk '!seen[$0]++' > failed_units.txt
cat failed_units.txt
