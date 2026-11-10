#!/bin/bash
# Fix the skeleton first (it is only read when an account is created), then create dana.
cat skel-spec.txt
ls -la etc/skel etc/skel/.ssh
cp usr/share/base-files/dot.profile etc/skel/.profile
cp usr/share/base-files/dot.bashrc etc/skel/.bashrc
cp usr/share/base-files/dot.bash_logout etc/skel/.bash_logout
chmod 644 etc/skel/.profile etc/skel/.bashrc etc/skel/.bash_logout
rm etc/skel/.bash_history etc/skel/.ssh/id_rsa
chmod 700 etc/skel/.ssh
chmod 600 etc/skel/.ssh/authorized_keys
bin/useradd -m dana
ls -la home/dana home/dana/.ssh
