#!/bin/bash
# Parse mountinfo by position relative to the "-" separator. A mount whose root
# is not "/" is a bind of a subdirectory: its source is the place its device is
# mounted normally (the root="/" line of the same major:minor) plus the root.
awk '
  { for (i = 7; $i != "-"; i++); fs = $(i + 1)
    if (fs !~ /^(ext[234]|xfs)$/) next
    if ($4 == "/") main[$3] = $5; else { n++; bmp[n] = $5; bdev[n] = $3; broot[n] = $4 } }
  END { for (k = 1; k <= n; k++) { m = main[bdev[k]]; if (m == "/") m = ""; print bmp[k], m broot[k] } }
' mountinfo.txt | sort > binds.txt
awk '{ print $1 "/" }' binds.txt > backup-excludes.txt
cat binds.txt backup-excludes.txt
