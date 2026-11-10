#!/bin/bash
readlink sysroot/etc/systemd/system/default.target
ls sysroot/usr/lib/systemd/system/*.target
ln -sfn /usr/lib/systemd/system/multi-user.target sysroot/etc/systemd/system/default.target
readlink sysroot/etc/systemd/system/default.target
