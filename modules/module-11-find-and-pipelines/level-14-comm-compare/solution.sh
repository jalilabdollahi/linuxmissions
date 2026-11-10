#!/bin/bash
# Reduce both dumps to sorted, unique package names, then let comm split them.
head -3 web1.pkgs web2.pkgs
cut -f1 web1.pkgs | sed 's/:.*//' | sort -u > web1.names
cut -f1 web2.pkgs | sed 's/:.*//' | sort -u > web2.names
comm -23 web1.names web2.names > only-web1.txt
comm -13 web1.names web2.names > only-web2.txt
cat only-web1.txt only-web2.txt
