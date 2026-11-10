#!/bin/bash
SANDBOX="$1"

# `ss -tan` on web-03 (10.20.4.17), iproute2 6.x column layout.
cat > "$SANDBOX/ss-output.txt" <<'EOF'
State     Recv-Q Send-Q          Local Address:Port            Peer Address:Port Process
LISTEN    0      4096            127.0.0.53%lo:53                   0.0.0.0:*
LISTEN    0      128                   0.0.0.0:22                   0.0.0.0:*
LISTEN    0      511                   0.0.0.0:80                   0.0.0.0:*
LISTEN    0      511                   0.0.0.0:443                  0.0.0.0:*
LISTEN    0      244                 127.0.0.1:5432                 0.0.0.0:*
LISTEN    0      511                 127.0.0.1:6379                 0.0.0.0:*
LISTEN    0      4096               10.20.4.17:8443                 0.0.0.0:*
ESTAB     0      0                  10.20.4.17:22               10.20.4.101:51544
ESTAB     0      36                 10.20.4.17:443             203.0.113.77:40112
ESTAB     0      0                   127.0.0.1:5432               127.0.0.1:48810
ESTAB     0      0                   127.0.0.1:48810              127.0.0.1:5432
TIME-WAIT 0      0                  10.20.4.17:443             198.51.100.23:39222
LISTEN    0      128                      [::]:22                      [::]:*
LISTEN    0      511                      [::]:80                      [::]:*
LISTEN    0      4096                    [::1]:631                     [::]:*
LISTEN    0      4096                        *:9100                       *:*
ESTAB     0      0                  10.20.4.17:35870            10.20.4.30:3306
SYN-SENT  0      1                  10.20.4.17:44188            10.20.4.88:25
EOF
