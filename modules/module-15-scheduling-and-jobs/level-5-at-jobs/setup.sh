#!/bin/bash
# Wrong Hour in the Queue: three at jobs; two are due at 15:00 today and only
# `at -c` shows which one is the database restart (it belongs at 03:00).
# The at/atq/atrm mock below keeps Debian at's spool format:
#   var/spool/cron/atjobs/<queue><jobno, 5 hex><minutes since epoch, 8 hex>
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin var/spool/cron/atjobs

cat > change-ticket.txt <<'TXT'
CHG-4471  main database maintenance, Wed 17 -> Thu 18 September
Owner: Ines Duarte (on leave from today, 12:00)

Queued with at on the dbadmin account:
  - cache flush                 today 15:00   (after the lunch peak, OK)
  - restart of the main DB      tomorrow 03:00 (low-traffic window)
  - archive of the app logs     tomorrow 03:30
TXT

cat > bin/at <<'PY'
#!/usr/bin/env python3
"""Mock at/atq/atrm for LinuxMissions (Debian at 3.2 behaviour, simplified).

Jobs are stored like atd stores them, in $LM_AT_SPOOL (default
<sandbox>/var/spool/cron/atjobs), and never run. The clock is frozen at
$LM_AT_NOW. Supported:
  at [-q Q] [-f FILE] [-m] [-v] TIMESPEC     at -l | atq [-q Q]
  at -r|-d JOB... | atrm JOB...              at -c JOB...
TIMESPEC: now | HH:MM | HHMM | H[:MM]am/pm | noon | midnight | teatime,
then optionally today | tomorrow | YYYY-MM-DD | MM/DD/YY | DD.MM.YY |
a weekday name, then optionally + N minutes|hours|days|weeks.
"""
import datetime as dt
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPOOL = os.environ.get("LM_AT_SPOOL", os.path.join(ROOT, "var/spool/cron/atjobs"))
NOW = dt.datetime.strptime(os.environ.get("LM_AT_NOW", "2025-09-17 11:20"), "%Y-%m-%d %H:%M")
USER = os.environ.get("LM_AT_USER", "dbadmin")
EPOCH = dt.datetime(1970, 1, 1)
PROG = os.path.basename(sys.argv[0])
DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
UNITS = {"min": 1, "minute": 1, "minutes": 1, "hour": 60, "hours": 60,
         "day": 1440, "days": 1440, "week": 10080, "weeks": 10080}


def die(*msgs, code=1):
    for m in msgs:
        print(m, file=sys.stderr)
    sys.exit(code)


def jobs():
    out = []
    for name in sorted(os.listdir(SPOOL)):
        m = re.fullmatch(r"([a-z])([0-9a-f]{5})([0-9a-f]{8})", name)
        if m:
            when = EPOCH + dt.timedelta(minutes=int(m.group(3), 16))
            out.append((int(m.group(2), 16), m.group(1), when, os.path.join(SPOOL, name)))
    return out


def ctime(t):
    return t.strftime("%a %b ") + f"{t.day:2d}" + t.strftime(" %H:%M:%S %Y")


def garbled(tok):
    die(f"syntax error. Last token seen: {tok}", "Garbled time")


def parse_time(words):
    toks = re.findall(r"\d+:\d+|\d+|[a-z]+|[+/.\-]", " ".join(words).lower())
    if not toks:
        garbled("")
    i, day_given = 0, False
    t = toks[0]
    if t == "now":
        when, day_given, i = NOW, True, 1
    else:
        if t in ("today", "tomorrow") or t[:3] in DAYS or re.fullmatch(r"\d{4}", t) and toks[1:2] == ["-"]:
            toks.insert(0, NOW.strftime("%H:%M"))
            t = toks[0]
        if t in ("noon", "midnight", "teatime"):
            h, mi = {"noon": (12, 0), "midnight": (0, 0), "teatime": (16, 0)}[t]
            i = 1
        elif re.fullmatch(r"\d+:\d+", t):
            h, mi = map(int, t.split(":"))
            i = 1
        elif re.fullmatch(r"\d{3,4}", t):
            h, mi = int(t[:-2]), int(t[-2:])
            i = 1
        elif re.fullmatch(r"\d{1,2}", t) and len(toks) > 1 and toks[1] in ("am", "pm"):
            h, mi = int(t), 0
            i = 1
        else:
            garbled(t)
        if i < len(toks) and toks[i] in ("am", "pm"):
            if not 1 <= h <= 12:
                garbled(toks[i])
            h = h % 12 + (12 if toks[i] == "pm" else 0)
            i += 1
        if h > 23 or mi > 59:
            garbled(t)
        when = NOW.replace(hour=h, minute=mi)
        rest = toks[i:]
        if rest[:1] == ["today"]:
            day_given, i = True, i + 1
        elif rest[:1] == ["tomorrow"]:
            when += dt.timedelta(days=1)
            day_given, i = True, i + 1
        elif len(rest) >= 5 and rest[1] == "-" and rest[3] == "-":
            try:
                when = when.replace(year=int(rest[0]), month=int(rest[2]), day=int(rest[4]))
            except ValueError:
                garbled(rest[4])
            day_given, i = True, i + 5
        elif len(rest) >= 5 and rest[1] in ("/", ".") and rest[3] == rest[1]:
            a, b, y = int(rest[0]), int(rest[2]), int(rest[4])
            mo, d = (a, b) if rest[1] == "/" else (b, a)
            try:
                when = when.replace(year=y + 2000 if y < 100 else y, month=mo, day=d)
            except ValueError:
                garbled(rest[4])
            day_given, i = True, i + 5
        elif rest and rest[0][:3] in DAYS and rest[0] in (rest[0][:3], rest[0][:3] + "day", "tues", "wednes", "thurs", "satur"):
            ahead = (DAYS.index(rest[0][:3]) - when.weekday()) % 7
            when += dt.timedelta(days=ahead)
            if when < NOW:
                when += dt.timedelta(days=7)
            day_given, i = True, i + 1
    if not day_given and when < NOW:
        when += dt.timedelta(days=1)
    rest = toks[i:]
    if rest:
        if rest[0] == "+" and len(rest) == 3 and rest[1].isdigit() and rest[2] in UNITS:
            when += dt.timedelta(minutes=int(rest[1]) * UNITS[rest[2]])
        else:
            garbled(rest[-1] if rest[0] == "+" else rest[0])
    if when < NOW.replace(second=0):
        die("at: refusing to create job destined in the past")
    return when


def shell_escape(text):
    """Quote the way atd's job files do: a backslash before each special character."""
    out = []
    for ch in text:
        if ch == "\n":
            out.append('"\n"')
        elif ch.isalnum() or ch in "_/.,:=@%+-":
            out.append(ch)
        else:
            out.append("\\" + ch)
    return "".join(out)


def env_lines():
    skip = {"TERM", "DISPLAY", "_", "SHELLOPTS", "BASH_VERSINFO", "EUID", "GROUPS", "PPID", "UID"}
    out = []
    for k, v in os.environ.items():
        if k in skip or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k) or k.startswith("LM_"):
            continue
        out.append(f"{k}={shell_escape(v)}; export {k}")
    return out


def submit(argv):
    queue, infile, verbose = "a", None, False
    while argv and argv[0].startswith("-") and argv[0] != "-":
        opt = argv.pop(0)
        if opt == "-q":
            queue = argv.pop(0) if argv else die(f"{PROG}: option requires an argument -- 'q'")
        elif opt == "-f":
            infile = argv.pop(0) if argv else die(f"{PROG}: option requires an argument -- 'f'")
        elif opt in ("-m", "-M"):
            pass
        elif opt == "-v":
            verbose = True
        else:
            die(f"{PROG}: invalid option -- '{opt.lstrip('-')[:1]}'",
                "Usage: at [-V] [-q x] [-f file] [-u username] [-mMlbv] timespec ...")
    if not re.fullmatch(r"[a-zA-Z]", queue):
        die("at: Queue must be a single letter")
    when = parse_time(argv) if argv else garbled("")
    if infile:
        try:
            cmds = open(infile).read()
        except OSError as e:
            die(f"at: cannot open input file {infile}: {e.strerror}")
    elif sys.stdin.isatty():
        die("at (mock): the at> prompt needs Ctrl-D, which this game cannot send.",
            "Give the commands on standard input instead, for example:",
            "  echo '/path/to/command --opt' | at 03:00 tomorrow")
    else:
        cmds = sys.stdin.read()
    if verbose:
        print(ctime(when), file=sys.stderr)
    seqf = os.path.join(SPOOL, ".SEQ")
    try:
        seq = int(open(seqf).read().strip() or "0", 16) + 1
    except (OSError, ValueError):
        seq = 1
    with open(seqf, "w") as f:
        f.write(f"{seq:x}\n")
    minutes = int((when - EPOCH).total_seconds() // 60)
    path = os.path.join(SPOOL, f"{queue}{seq:05x}{minutes:08x}")
    delim = f"marcinDELIMITER{os.urandom(4).hex()}"
    with open(path, "w") as f:
        f.write("#!/bin/sh\n")
        f.write(f"# atrun uid={os.getuid()} gid={os.getgid()}\n")
        f.write(f"# mail {USER:>8} 0\n")
        mask = os.umask(0); os.umask(mask)
        f.write(f"umask {mask:o}\n")
        f.write("\n".join(env_lines()) + "\n")
        f.write(f"cd {shell_escape(os.getcwd())} || {{\n"
                "\t echo 'Execution directory inaccessible' >&2\n\t exit 1\n}\n")
        f.write(f"${{SHELL:-/bin/sh}} << '{delim}'\n{cmds}")
        if cmds and not cmds.endswith("\n"):
            f.write("\n")
        f.write(f"{delim}\n")
    os.chmod(path, 0o700)
    print("warning: commands will be executed using /bin/sh", file=sys.stderr)
    print(f"job {seq} at {ctime(when)}", file=sys.stderr)


def main():
    argv = sys.argv[1:]
    mode = {"atq": "-l", "atrm": "-r"}.get(PROG)
    if mode is None and argv and argv[0] in ("-l", "-r", "-d", "-c"):
        mode = argv.pop(0)
    if mode == "-l":
        queue = None
        if len(argv) >= 2 and argv[0] == "-q":
            queue = argv[1]
        for num, q, when, _ in sorted(jobs(), key=lambda j: (j[2], j[0])):
            if queue is None or q == queue:
                print(f"{num}\t{ctime(when)} {q} {USER}")
        return
    if mode in ("-r", "-d", "-c"):
        if not argv:
            die(f"Usage: {'atrm' if mode != '-c' else 'at -c'} job ...")
        found = {str(n): p for n, _, _, p in jobs()}
        rc = 0
        for j in argv:
            if j not in found:
                print(f"Cannot find jobid {j}", file=sys.stderr)
                rc = 1
            elif mode == "-c":
                sys.stdout.write(open(found[j]).read())
            else:
                os.remove(found[j])
        sys.exit(rc)
    submit(argv)


if __name__ == "__main__":
    main()
PY
chmod 755 bin/at
ln -sf at bin/atq
ln -sf at bin/atrm

# Ines's three jobs, as `at` stored them when she queued them this morning.
# Ines's three jobs, as atd stored them when she queued them this morning
# (from /home/dbadmin, with her login environment).
queue_job() {  # JOBNO MINUTES_SINCE_EPOCH COMMAND
  local f
  f="$(printf 'var/spool/cron/atjobs/a%05x%08x' "$1" "$2")"
  cat > "$f" <<JOB
#!/bin/sh
# atrun uid=$(id -u) gid=$(id -g)
# mail  dbadmin 0
umask 22
HOME=/home/dbadmin; export HOME
LANG=C.UTF-8; export LANG
LOGNAME=dbadmin; export LOGNAME
MAIL=/var/mail/dbadmin; export MAIL
PATH=/usr/local/bin:/usr/bin:/bin; export PATH
PGHOST=db-main.internal; export PGHOST
PWD=/home/dbadmin; export PWD
SHELL=/bin/bash; export SHELL
USER=dbadmin; export USER
cd /home/dbadmin || {
	 echo 'Execution directory inaccessible' >&2
	 exit 1
}
\${SHELL:-/bin/sh} << 'marcinDELIMITER$3'
$4
marcinDELIMITER$3
JOB
  chmod 700 "$f"
}
# minutes since the epoch: 2025-09-17 15:00 = 29302020, 2025-09-18 03:30 = 29302770
queue_job 4 29302020 1f6b20c4 "/usr/local/bin/pgctl restart main --mode=fast"
queue_job 5 29302020 6e01d9a7 "/usr/local/bin/cache-flush --all --region eu"
queue_job 6 29302770 0c4f83be "/usr/local/bin/log-archive --compress /var/log/app"
printf '%x\n' 6 > var/spool/cron/atjobs/.SEQ
