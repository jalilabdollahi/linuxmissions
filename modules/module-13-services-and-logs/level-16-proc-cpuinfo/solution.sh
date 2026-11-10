#!/bin/bash
# Physical cores = distinct (physical id, core id) pairs; AVX2 = the whole
# word avx2 in the flags. Then restart the service so it reads the file.
grep -c '^processor' capture/cpuinfo
grep -E '^(physical id|core id)' capture/cpuinfo | paste - - | sort -u | wc -l
cores=$(grep -E '^(physical id|core id)' capture/cpuinfo | paste - - | sort -u | wc -l)
if grep '^flags' capture/cpuinfo | grep -qw avx2; then build=avx2; else build=generic; fi
sed -i "s/^WORKERS=.*/WORKERS=$cores/; s/^BUILD=.*/BUILD=$build/" etc/default/render-worker
grep -v '^#' etc/default/render-worker
bin/systemctl restart render-worker.service
bin/systemctl status render-worker.service
