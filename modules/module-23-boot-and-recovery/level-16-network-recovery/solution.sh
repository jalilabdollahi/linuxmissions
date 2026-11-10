#!/bin/bash
N=sysroot/etc/systemd/network
read -r _ LMAC LADDR _ LGW _ < <(grep '^LAN ' ticket.txt)
read -r _ BMAC _ < <(grep '^BACKUP ' ticket.txt)
LIF=$(awk -v m="$LMAC" 'index($0,m){sub(":","",$2); print $2}' ip-o-link.txt)
BIF=$(awk -v m="$BMAC" 'index($0,m){sub(":","",$2); print $2}' ip-o-link.txt)
sed -i -e "s|^Name=.*|Name=$LIF|" -e "s|^Address=.*|Address=$LADDR|" -e "s|^Gateway=.*|Gateway=$LGW|" $N/10-lan.network
sed -i "s|^MACAddress=.*|Name=$BIF|" $N/20-backup.network
cat $N/*.network
