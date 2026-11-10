#!/bin/bash
# Kernel OOM lines: keep only kills in reports.service's own cgroup, take the
# largest anon-rss (kB = KiB), x1.5, round up to 256 MiB, set it, start again.
bin/journalctl -k -g 'oom-kill:|Killed process' --no-pager
pids=$(bin/journalctl -k -g 'task_memcg=/system.slice/reports.service,' -o cat | sed 's/.*,pid=\([0-9]*\),.*/\1/')
peak=$(for p in $pids; do bin/journalctl -k -g "Killed process $p " -o cat; done | sed 's/.*anon-rss:\([0-9]*\)kB.*/\1/' | sort -n | tail -1)
mib=$(( (peak * 3 + 2047) / 2048 ))      # ceil(peak kB x 1.5 / 1024) in MiB
new=$(( (mib + 255) / 256 * 256 ))
echo "peak anon-rss ${peak} kB -> MemoryMax=${new}M"
bin/systemctl set-property reports.service MemoryMax=${new}M
bin/systemctl show -p MemoryMax reports.service
bin/systemctl start reports.service
