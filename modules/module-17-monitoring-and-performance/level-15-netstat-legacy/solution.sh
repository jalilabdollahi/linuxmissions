#!/bin/bash
cat > conn_states.sh <<'LMEND'
#!/bin/bash
# conn_states.sh - number of TCP connections per state (feeds the dashboards)
ss -tan | awk 'NR>1 {s=$1; if (s=="ESTAB") s="ESTABLISHED"; gsub("-","_",s); sub("_WAIT_","_WAIT",s); c[s]++} END {for (s in c) print s, c[s]}' | sort
LMEND
