#!/bin/bash
APP=$(grep -ho '/opt/[a-z]*/bin' sysroot/etc/profile.d/*.sh | head -n1)
echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' > sysroot/etc/environment
rm sysroot/etc/profile.d/90-legacy.sh sysroot/home/deploy/.bash_profile
echo "PATH=\$PATH:$APP" > sysroot/etc/profile.d/10-app.sh
sed -i '/opt\//d' sysroot/home/deploy/.profile
./login-sim deploy; ./login-sim ops
