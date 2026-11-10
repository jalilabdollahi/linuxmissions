#!/bin/bash
# The member list of the docker line, plus everyone whose primary GID is docker's.
grep -n docker etc/group
g=$(awk -F: '$1 == "docker" { print $3 }' etc/group)
{
  awk -F: '$1 == "docker" { print $4 }' etc/group | tr ',' '\n'
  awk -F: -v g="$g" '$4 == g { print $1 }' etc/passwd
} | grep -v '^$' | sort -u > docker-members.txt
cat docker-members.txt
