#!/bin/bash
# When the Box Is Idle: queue app/reindex.sh with batch so that the job,
# replayed later by atd, runs in app/ with DATA_DIR exported. at/batch save
# the exported environment and the current directory when the job is queued.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin app data var/spool/cron/atjobs

cat > RUNBOOK.txt <<'TXT'
Search index rebuild
====================
reindex.sh is heavy. Do NOT run it in your shell; hand it to batch, which starts
it as soon as the load average is low (usually in the night).

reindex.sh needs:
  * its working directory = app/   (it reads ./reindex.conf)
  * DATA_DIR = the data directory, full path  (it reads products.csv there and
    writes DATA_DIR/index/search.idx)

Last attempt (Tue): queued from the home directory, died at 02:14 with
"DATA_DIR: DATA_DIR is not set". The failed job was removed with atrm.
TXT

cat > app/reindex.conf <<'CONF'
# search index settings
INDEX_NAME=products-v3
MIN_TERM_LENGTH=3
CONF
cat > app/reindex.sh <<'SH'
#!/bin/bash
# Rebuild the product search index. Heavy: always run it through batch.
set -u
: "${DATA_DIR:?DATA_DIR is not set}"
if [ ! -r reindex.conf ]; then
  echo "reindex: no reindex.conf in $(pwd); run me from app/" >&2
  exit 2
fi
. ./reindex.conf
if [ ! -r "$DATA_DIR/products.csv" ]; then
  echo "reindex: $DATA_DIR/products.csv not found" >&2
  exit 3
fi
mkdir -p "$DATA_DIR/index"
{
  echo "# index $INDEX_NAME built from $DATA_DIR/products.csv"
  tail -n +2 "$DATA_DIR/products.csv" | cut -d, -f2 | tr 'A-Z ' 'a-z\n' |
    awk -v min="$MIN_TERM_LENGTH" 'length($0) >= min' | sort | uniq -c | sort -k1,1nr -k2
} > "$DATA_DIR/index/search.idx"
echo "reindex: $INDEX_NAME rebuilt"
SH
chmod 755 app/reindex.sh

{
  echo "sku,title,price"
  i=0
  for t in "Trail Running Shoe" "Rain Jacket Light" "Running Socks Merino" "Trail Map Alps" \
           "Merino Base Layer" "Jacket Repair Kit" "Running Belt" "Alps Hut Guide"; do
    i=$((i + 1)); echo "SKU-$((1000 + i * 7)),$t,$((i * 13 + 9)).90"
  done
} > data/products.csv

cat > bin/batch <<'PY'
#!/usr/bin/env python3
"""LinuxMissions mock of at's batch side (Debian at 3.2). Never runs a job.

  batch [-f FILE]            queue stdin (or FILE) in queue b, "now"
  at [-q Q] [-f FILE] now    queue in Q (default a); only "now" is understood here
  atq [-q Q] | at -l         list jobs
  at -c JOB                  print the script atd would run
  atrm JOB... | at -r JOB    remove jobs
The spool is var/spool/cron/atjobs next to bin/; the clock is frozen.
"""
import os
import sys
import time

BIN = os.path.dirname(os.path.abspath(__file__))
SPOOL = os.path.join(os.path.dirname(BIN), "var", "spool", "cron", "atjobs")
FROZEN = 29303835          # minutes since the epoch: Thu 2025-09-18 21:15 UTC
NOT_SAVED = ("TERM", "DISPLAY", "_", "SHELLOPTS", "BASH_VERSINFO", "EUID", "GROUPS", "PPID", "UID")


def when_text(minutes):
    return time.strftime("%a %b %e %H:%M:%S %Y", time.gmtime(minutes * 60))


def spooled():
    for name in sorted(os.listdir(SPOOL)):
        if len(name) == 14 and name[0].isalpha():
            try:
                yield int(name[1:6], 16), name[0], int(name[6:], 16), os.path.join(SPOOL, name)
            except ValueError:
                pass


def quote(value):
    safe = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/.,:=@%+-")
    return "".join(c if c in safe else ('"\n"' if c == "\n" else "\\" + c) for c in value)


def queue_job(queue, source):
    if source:
        try:
            with open(source) as f:
                commands = f.read()
        except OSError as err:
            sys.exit(f"at: cannot open input file {source}: {err.strerror}")
    elif sys.stdin.isatty():
        sys.exit("batch (mock): the at> prompt needs Ctrl-D, which this game cannot send.\n"
                 "Pipe the commands in instead:  echo 'COMMAND' | batch")
    else:
        commands = sys.stdin.read()
    seq_file = os.path.join(SPOOL, ".SEQ")
    try:
        with open(seq_file) as f:
            number = int(f.read().strip(), 16) + 1
    except (OSError, ValueError):
        number = 1
    with open(seq_file, "w") as f:
        f.write("%x\n" % number)
    mask = os.umask(0o22)
    os.umask(mask)
    marker = "marcinDELIMITER" + os.urandom(4).hex()
    script = ["#!/bin/sh", f"# atrun uid={os.getuid()} gid={os.getgid()}",
              "# mail %8s 0" % os.environ.get("USER", "player"), "umask %o" % mask]
    for key, value in os.environ.items():
        if key not in NOT_SAVED and key.replace("_", "a").isalnum() and not key[0].isdigit():
            script.append(f"{key}={quote(value)}; export {key}")
    script += [f"cd {quote(os.getcwd())} || {{", "\t echo 'Execution directory inaccessible' >&2",
               "\t exit 1", "}", "${SHELL:-/bin/sh} << '%s'" % marker]
    path = os.path.join(SPOOL, "%s%05x%08x" % (queue, number, FROZEN))
    with open(path, "w") as f:
        f.write("\n".join(script) + "\n" + commands + ("" if commands.endswith("\n") else "\n") + marker + "\n")
    os.chmod(path, 0o700)
    print("warning: commands will be executed using /bin/sh", file=sys.stderr)
    print(f"job {number} at {when_text(FROZEN)}", file=sys.stderr)


def main(prog, args):
    if prog == "atq" or args[:1] == ["-l"]:
        args = args[1:] if args[:1] == ["-l"] else args
        only = args[1] if args[:1] == ["-q"] and len(args) > 1 else None
        for number, queue, minutes, _ in spooled():
            if only in (None, queue):
                print(f"{number}\t{when_text(minutes)} {queue} {os.environ.get('USER', 'player')}")
        return 0
    if prog == "atrm" or args[:1] in (["-r"], ["-d"], ["-c"]):
        show = args[:1] == ["-c"]
        wanted = args[1:] if prog != "atrm" else args
        if not wanted:
            sys.exit("Usage: at -c job ..." if show else "Usage: atrm job ...")
        jobs = {str(n): p for n, _, _, p in spooled()}
        status = 0
        for job in wanted:
            if job not in jobs:
                print(f"Cannot find jobid {job}", file=sys.stderr)
                status = 1
            elif show:
                with open(jobs[job]) as f:
                    sys.stdout.write(f.read())
            else:
                os.remove(jobs[job])
        return status
    queue, source = ("b" if prog == "batch" else "a"), None
    while args and args[0].startswith("-"):
        flag = args.pop(0)
        if flag in ("-q", "-f") and not args:
            sys.exit(f"{prog}: option requires an argument -- '{flag[1]}'")
        if flag == "-q":
            queue = args.pop(0)
        elif flag == "-f":
            source = args.pop(0)
        elif flag == "-b":
            queue = "b"
        elif flag not in ("-m", "-M"):
            sys.exit(f"{prog}: invalid option -- '{flag[1:2]}'")
    if prog == "batch" and args:
        sys.exit("at: garbled time (batch takes no time: it starts the job when the load is low)")
    if prog != "batch" and [a.lower() for a in args] != ["now"]:
        sys.exit("at (mock): this sandbox only understands 'now' as a time; the reindex belongs in batch anyway")
    if len(queue) != 1 or not queue.isalpha():
        sys.exit("at: Queue must be a single letter")
    queue_job(queue, source)
    return 0


if __name__ == "__main__":
    sys.exit(main(os.path.basename(sys.argv[0]), sys.argv[1:]))
PY
chmod 755 bin/batch
for name in at atq atrm; do ln -sf batch "bin/$name"; done
printf '%x\n' 11 > var/spool/cron/atjobs/.SEQ
