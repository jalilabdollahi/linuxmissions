#!/bin/bash
# Others may write: startup files and scripts. Others may read: the secrets. Symlinks are skipped (! -type l).
{
  find home ! -type l -perm /022
  find home ! -type l \( -name .netrc -o -name .pgpass -o -name .my.cnf -o -name credentials -o -name .ssh -o -name id_ed25519 \) -perm /077
} | sort -u > findings.txt
find home ! -type l -perm /022 -exec chmod go-w {} +
find home ! -type l \( -name .netrc -o -name .pgpass -o -name .my.cnf -o -name credentials -o -name .ssh -o -name id_ed25519 \) -perm /077 -exec chmod go-rwx {} +
cat findings.txt
