#!/bin/bash
# Test the patch, apply what applies, finish the rejected hunk by hand, clean up.
patch -p1 --dry-run < fix-timeouts.patch
patch -p1 < fix-timeouts.patch
cat proxy.conf.rej
sed -i 's/^health_check_timeout 3s;$/health_check_timeout 5s;/' proxy.conf
rm -f proxy.conf.rej proxy.conf.orig
diff -u .lm-state/ours.conf proxy.conf
