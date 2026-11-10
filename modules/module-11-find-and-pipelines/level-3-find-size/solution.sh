#!/bin/bash
# -size +10M: more than 10 MiB (find rounds sizes UP to whole MiB, and
# exactly 10 MiB rounds to 10, which is not more than 10).
find outbox -type f -size +10M > oversize.txt
find outbox -type f -empty > empty.txt
cat oversize.txt empty.txt
