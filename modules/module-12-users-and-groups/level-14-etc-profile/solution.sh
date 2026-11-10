#!/bin/bash
# A new snippet ending in .sh, POSIX only, no output, with export.
cat it-notes.txt
ls etc/profile.d
cat > etc/profile.d/company-env.sh <<'EOT'
# company proxy and Java for every login shell
http_proxy=http://proxy.corp.example:3128
https_proxy=http://proxy.corp.example:3128
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export http_proxy https_proxy JAVA_HOME
EOT
env -i LM_ETC="$SANDBOX/etc" sh -c '. "$LM_ETC/profile"; printenv http_proxy https_proxy JAVA_HOME no_proxy'
