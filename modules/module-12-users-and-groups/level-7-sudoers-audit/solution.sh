#!/bin/bash
# Read the rules sudo reads: the main file, then the drop-ins it includes
# (skipping names with a dot or ending in ~), keep full ALL=(ALL...) ALL ones.
cat etc/sudoers
grep -v '^#[^i]' etc/sudoers | grep -n 'include'
ls etc/sudoers.d
grep -H . etc/sudoers.d/10-wheel etc/sudoers.d/30-ci etc/sudoers.d/50-hosts
grep -E '^(sudo|wheel):' etc/group
# sudo group, ADMINS alias (3 lines of names), wheel group, two drop-in accounts
{
  grep '^sudo:' etc/group | cut -d: -f4 | tr ',' '\n'
  grep '^wheel:' etc/group | cut -d: -f4 | tr ',' '\n'
  printf '%s\n' lena omar dmitri ci-runner vendor
} | sort -u | grep -vx root > root-capable.txt
cat root-capable.txt
