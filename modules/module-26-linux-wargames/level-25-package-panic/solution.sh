#!/bin/bash
S=sysroot/var/lib/dpkg/status
awk -v RS= -F'\n' '{ pkg=""; st=""; for(i=1;i<=NF;i++){ if($i ~ /^Package: /) pkg=substr($i,10); if($i ~ /^Status: /){ split($i,a," "); st=a[4] } } if(st!="installed") print pkg, st }' $S | sort > broken.txt
# installed versions, and one line per versioned single-package clause of installed packages
awk -v RS= -F'\n' '{ pkg="";ver="";st="";dep="";
  for(i=1;i<=NF;i++){ if($i~/^Package: /)pkg=substr($i,10); if($i~/^Version: /)ver=substr($i,10); if($i~/^Status: /){split($i,a," ");st=a[4]}
    if($i~/^(Pre-)?Depends: /){ sub(/^[^:]*: /,"",$i); dep=dep (dep==""?"":", ") $i } }
  if(st=="installed"){ print "V", pkg, ver; n=split(dep,c,/, */); for(j=1;j<=n;j++) if(c[j]!~/\|/ && match(c[j],/^[^ ]+ \(.*\)$/)){ split(c[j],t,/[ ()]+/); print "C", pkg, t[1], t[2], t[3] } } }' $S > .clauses
sort -r .clauses | awk '$1=="V"{v[$2]=$3} $1=="C"{print $2, $3, $4, $5, v[$3]}' \
 | while read -r c d op want have; do
     [ -n "$have" ] && ! dpkg --compare-versions "$have" "$op" "$want" && echo "$c $d"
   done | sort > unsatisfied.txt
awk '$2=="unpacked"||$2=="half-configured"||$2=="triggers-pending"||$2=="triggers-awaited"{print $1}' broken.txt > .set
awk -v RS= -F'\n' 'NR==FNR{for(i=1;i<=NF;i++)inset[$i]=1;next} { pkg="";dep="";for(i=1;i<=NF;i++){ if($i~/^Package: /)pkg=substr($i,10); if($i~/^(Pre-)?Depends: /){sub(/^[^:]*: /,"",$i);dep=dep ", " $i} }
  if(pkg in inset){ print pkg, pkg; n=split(dep,c,/, */); for(j=1;j<=n;j++){ split(c[j],t," "); if(t[1] in inset) print t[1], pkg } } }' .set $S | tsort > fix_order.txt
rm -f .clauses .set
