#!/bin/bash
./modprobe-sim -n -v ixgbe
grep -rn ixgbe sysroot/etc/modprobe.d/
sed -i 's/^install ixgbe/# install ixgbe/' sysroot/etc/modprobe.d/50-nic-workarounds.conf
./modprobe-sim -n -v ixgbe
