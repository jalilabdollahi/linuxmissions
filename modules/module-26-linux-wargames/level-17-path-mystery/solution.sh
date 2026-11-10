#!/bin/bash
cat deploy-sim
cd home/ci && grep -n deployctl .ci_env .bashrc .profile; cd ../..
ls -l home/ci/.local/bin usr/local/bin
rm home/ci/.local/bin/deployctl usr/local/bin/deployctl
sed -i '/^deployctl()/d' home/ci/.ci_env
printf '%s\n' "$PWD/home/ci/.ci_env" "$PWD/home/ci/.local/bin/deployctl" "$PWD/usr/local/bin/deployctl" > shadows.txt
./deploy-sim
