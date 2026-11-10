#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
apt-mark hold postgresql-16 linux-image-generic
apt-mark showhold
apt-get -s upgrade > upgrade-plan.txt
grep -E '^(Inst|The following)' upgrade-plan.txt
