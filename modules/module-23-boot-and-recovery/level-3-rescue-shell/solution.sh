#!/bin/bash
# The server's files live under sysroot/. Read its hostname, put it on the 127.0.1.1 line.
cat sysroot/etc/hostname
sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $(cat sysroot/etc/hostname)/" sysroot/etc/hosts
./sudo-in-sysroot true
