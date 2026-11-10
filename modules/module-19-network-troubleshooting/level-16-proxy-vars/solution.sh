#!/bin/bash
# Keep the proxy URL, write all six variables, and use the suffix form
# ".internal" that curl understands.
p=$(grep -m1 '^export http_proxy=' proxy.env | cut -d= -f2-)
cat > proxy.env <<EOT
# Corporate proxy (NET-2231). Every job does: . ./proxy.env
export http_proxy=$p
export https_proxy=$p
export no_proxy=localhost,127.0.0.1,.internal
export HTTP_PROXY=\$http_proxy
export HTTPS_PROXY=\$https_proxy
export NO_PROXY=\$no_proxy
EOT
./check-access.sh
