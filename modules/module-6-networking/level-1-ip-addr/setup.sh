#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/ip_addr.txt" <<'EOF'
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    inet 127.0.0.1/8 scope host lo
2: eth0: <BROADCAST,UP,LOWER_UP> mtu 1500
    inet 192.168.56.20/24 brd 192.168.56.255 scope global eth0
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 10.0.0.44/24 brd 10.0.0.255 scope global wlan0
EOF
