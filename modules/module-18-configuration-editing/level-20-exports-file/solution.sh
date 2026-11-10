#!/bin/bash
export PATH="$PWD/bin:$PATH"   # in the game the sandbox bin/ is first on PATH already
# Remove the space that detached the options from the subnet, drop no_root_squash, apply.
sed -i -e 's|\(10\.20\.0\.0/24\) (|\1(|' -e 's/,no_root_squash//' etc/exports
exportfs -r
exportfs -v
