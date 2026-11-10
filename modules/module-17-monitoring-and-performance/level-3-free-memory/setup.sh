#!/bin/bash
# Two `free -m` captures (free1.txt, free2.txt) plus /proc/meminfo of the second.
# "free" is tiny every time (page cache). One of three random scenarios:
#   ok         plenty available, swap used identical in both captures
#   swap       available above 10 %, but swap used grew between captures
#   available  available below 10 % of total, swap flat
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
scen = R.choice(["ok", "swap", "available"])
total = R.choice([7821, 7953, 15953, 15989, 31871])
swap_total = 4095
free1, free2 = R.randint(150, 195), R.randint(150, 195)
shared = R.randint(40, 400)
swap1 = R.randint(180, 900)
if scen == "ok":
    avail1 = int(total * R.uniform(0.22, 0.4)); avail2 = int(total * R.uniform(0.22, 0.4))
    swap2 = swap1
elif scen == "swap":
    avail1 = int(total * R.uniform(0.2, 0.3)); avail2 = int(total * R.uniform(0.12, 0.18))
    swap2 = swap1 + R.randint(250, 800)
else:
    avail1 = int(total * R.uniform(0.14, 0.2)); avail2 = int(total * R.uniform(0.04, 0.09))
    swap2 = swap1
verdict = "pressure" if (avail2 * 10 < total or swap2 > swap1) else "ok"

def free_txt(avail, fr, swap_used):
    used = total - avail
    cache = avail - fr
    out = ["               total        used        free      shared  buff/cache   available",
           "Mem:    %11d %11d %11d %11d %11d %11d" % (total, used, fr, shared, cache, avail),
           "Swap:   %11d %11d %11d" % (swap_total, swap_used, swap_total - swap_used)]
    return "\n".join(out) + "\n"
open("free1.txt", "w").write("$ free -m    # 09:50\n" + free_txt(avail1, free1, swap1))
open("free2.txt", "w").write("$ free -m    # 10:00\n" + free_txt(avail2, free2, swap2))
buffers = R.randint(100, 400); cached = avail2 - free2 - buffers
if cached < 0:
    buffers = 0; cached = avail2 - free2
kb = lambda m: m * 1024
open("meminfo2.txt", "w").write(
"MemTotal:       %d kB\nMemFree:        %d kB\nMemAvailable:   %d kB\nBuffers:        %d kB\nCached:         %d kB\n"
"SwapCached:     %d kB\nSwapTotal:      %d kB\nSwapFree:       %d kB\nShmem:          %d kB\n" % (
    kb(total), kb(free2), kb(avail2), kb(buffers), kb(cached), kb(min(swap2, 60)), kb(swap_total), kb(swap_total - swap2), kb(shared)))
open("memory.env", "w").write("available_mib=\nswap_used_mib=\nverdict=\n")
open(".lm-state/want", "w").write("AVAIL=%d\nSWAP=%d\nVERDICT=%s\nFREE2=%d\nSCEN=%s\n" % (avail2, swap2, verdict, free2, scen))
PY
cat > TICKET.md <<'LMEND'
# MEM-7741: "server out of memory, under 200 MB free!"

Files:
- free1.txt     free -m at 09:50
- free2.txt     free -m at 10:00 (ten minutes later)
- meminfo2.txt  /proc/meminfo at 10:00

Answer in memory.env, using the LATER capture (10:00):

    available_mib=    MiB the system can still give to programs without swapping
    swap_used_mib=    MiB of swap in use
    verdict=          pressure  or  ok

Rule for the verdict: it is `pressure` when available memory is below 10 % of
total memory, OR when swap used at 10:00 is larger than at 09:50 (the box has
started pushing memory out). Otherwise it is `ok`.
LMEND
