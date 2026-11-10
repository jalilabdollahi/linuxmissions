#!/bin/bash
# Look first (-n changes nothing), then repair with -f (force: the image says "clean")
# and -y (answer yes), keeping the output and the exit code of that run.
e2fsck -fn data.img > /dev/null; echo "read-only check exit: $?"
e2fsck -fy data.img > fsck.log 2>&1
echo $? > fsck_exit.txt
cat fsck_exit.txt
e2fsck -fn data.img
