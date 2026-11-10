#!/bin/bash
# -w 70 is the width, -s prefers breaking after a space; the long URL still gets cut.
fold -s -w 70 alert.txt > alert.sms
awk '{ print length($0) ": " $0 }' alert.sms | head -5
