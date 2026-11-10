#!/bin/bash
export PATH="$SANDBOX/bin:$PATH"
dpkg -l | grep -i oldmon
apt-get purge -y oldmon
dpkg -l | grep -i oldmon
