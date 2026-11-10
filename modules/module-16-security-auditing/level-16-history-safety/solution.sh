#!/bin/bash
sed -i -E -e '/^(mysql|mysqldump) .*(-p[^[:space:]]|-p [[:punct:]]|--password=)/d' -e '/^export (API_TOKEN|[A-Z_]*PASSWORD)=/d' home/.bash_history
echo 'HISTCONTROL=ignorespace' >> home/.bashrc
