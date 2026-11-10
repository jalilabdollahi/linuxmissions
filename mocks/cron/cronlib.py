"""Cron semantics shared by the LinuxMissions cron mocks.

Behaves like Debian cron 3.0pl1 as shipped in Ubuntu 24.04 (the reference
image), ported from its parser (entry.c, env.c, misc.c) so that error
messages, line numbers and edge cases match:

* five time fields with numbers, names (jan..dec, sun..sat, 3 letters,
  any case), ranges, lists and steps (`*/15`, `1-30/10`); a single number
  with a step (`5/10`) is an error; a reversed range (`5-1`) selects nothing;
* day-of-week 0-7 (0 and 7 are Sunday);
* the day rule: if the day-of-month or the day-of-week field starts with
  `*`, both must match; otherwise either may match (so `*/2` counts as `*`);
* @reboot @yearly @annually @monthly @weekly @daily @midnight @hourly;
* `NAME = value` environment lines (quotes allowed); they apply to the job
  lines that follow them;
* `%` in the command: the first unescaped `%` ends the command, the rest is
  fed to the job's stdin with every `%` turned into a newline; `\\%` is a
  literal `%`.

Only the standard library is used; works on Linux and macOS.
Pure functions here, command line tools in the sibling files:
crontab (mock), cron-run (runs jobs on a simulated clock), cron-expand
(lists fire times), run-parts (mock) and systemd-analyze (calendar only).
"""
from __future__ import annotations

import datetime as _dt
import os
import re
import stat as _stat
from dataclasses import dataclass, field

__all__ = [
    "CronError", "Entry", "Crontab", "parse_crontab", "parse_line", "check_install",
    "expand", "next_runs", "split_command", "valid_crond_name", "valid_runparts_name",
    "run_parts_list", "parse_anacrontab", "parse_time", "DEBIAN_PERIODIC",
    "NHEADER_LINES", "strip_header", "make_header", "DEFAULT_PATH",
]

FIRST_MINUTE, LAST_MINUTE = 0, 59
FIRST_HOUR, LAST_HOUR = 0, 23
FIRST_DOM, LAST_DOM = 1, 31
FIRST_MONTH, LAST_MONTH = 1, 12
FIRST_DOW, LAST_DOW = 0, 7

MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
DOW_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

ECODES = ["no error", "bad minute", "bad hour", "bad day-of-month", "bad month",
          "bad day-of-week", "bad command", "bad time specifier", "bad username",
          "command too long"]
E_NONE, E_MINUTE, E_HOUR, E_DOM, E_MONTH, E_DOW, E_CMD, E_TIMESPEC, E_USERNAME, E_CMD_LEN = range(10)

MAX_COMMAND = 1000
MAX_ENVSTR = 1000
MAX_TEMPSTR = 100
MAX_TAB_LINES = 1000
NHEADER_LINES = 3
DEFAULT_PATH = "/usr/bin:/bin"
DEFAULT_SHELL = "/bin/sh"
RCSID = "$Id: crontab.c,v 2.13 1994/01/17 03:20:37 vixie Exp $"

# What Ubuntu's /etc/crontab does with the periodic directories (minute hour dom mon dow).
DEBIAN_PERIODIC = [
    ("hourly", "17 * * * *"),
    ("daily", "25 6 * * *"),
    ("weekly", "47 6 * * 7"),
    ("monthly", "52 6 1 * *"),
]

EOF = -1


class CronError(Exception):
    """A crontab could not be parsed; .messages holds crontab(1)-style lines."""

    def __init__(self, messages):
        super().__init__("\n".join(messages))
        self.messages = list(messages)


# ─── the character stream (port of get_char / unget_char / LineNumber) ──────

class _Stream:
    def __init__(self, text: str, line: int = 1):
        self.text = text
        self.pos = 0
        self.line = line

    def get(self) -> int:
        if self.pos >= len(self.text):
            self.pos = len(self.text) + 1   # reading past EOF is sticky
            return EOF
        ch = self.text[self.pos]
        self.pos += 1
        if ch == "\n":
            self.line += 1
        return ch  # type: ignore[return-value]

    def unget(self, ch) -> None:
        if ch == EOF:
            return
        self.pos -= 1
        if ch == "\n":
            self.line -= 1

    def get_string(self, terms: str, size: int):
        out = []
        while True:
            ch = self.get()
            if ch == EOF or ch in terms:
                break
            if size > 1:
                out.append(ch)
                size -= 1
        return ch, "".join(out)


def _isspace(ch) -> bool:
    return ch != EOF and ch in " \t\n\r\f\v"


def _isalnum(ch) -> bool:
    return ch != EOF and ch.isascii() and ch.isalnum()


def _skip_comments(f: _Stream) -> None:
    ch = EOF
    while True:
        ch = f.get()
        if ch == EOF:
            break
        while ch in (" ", "\t"):
            ch = f.get()
        if ch == EOF:
            break
        if ch != "\n" and ch != "#":
            break
        while ch != "\n" and ch != EOF:
            ch = f.get()
    if ch != EOF:
        f.unget(ch)


def _load_env(f: _Stream):
    """Port of env.c load_env: returns (status, 'NAME=value' or raw line).

    status: None = EOF (ERR), False = not an env line, True = env line.
    """
    filepos, fileline = f.pos, f.line
    _skip_comments(f)
    ch, envstr = f.get_string("\n", MAX_ENVSTR - 1)
    if ch == EOF:
        return None, envstr
    NAMEI, NAME, EQ1, EQ2, VALUEI, VALUE, FINI, ERROR = range(8)
    name, val = [], []
    cur = name
    state = NAMEI
    quote = ""
    i = 0
    while state != ERROR and i < len(envstr):
        c = envstr[i]
        if state in (NAMEI, VALUEI):
            if c in ("'", '"'):
                quote = c
                i += 1
            state += 1
            if i >= len(envstr):
                break
            c = envstr[i]
        if state in (NAME, VALUE):
            if quote:
                if c == quote:
                    state += 1
                    i += 1
                    continue
                if state == NAME and c == "=":
                    state = ERROR
                    continue
            elif state == NAME:
                if _isspace(c):
                    i += 1
                    state += 1
                    continue
                if c == "=":
                    state += 1
                    continue
            cur.append(c)
            i += 1
        elif state == EQ1:
            if c == "=":
                state += 1
                cur = val
                quote = ""
            elif not _isspace(c):
                state = ERROR
            i += 1
        elif state in (EQ2, FINI):
            if _isspace(c):
                i += 1
            else:
                state += 1
    if state != FINI and not (state == VALUE and not quote):
        f.pos, f.line = filepos, fileline
        return False, envstr
    value = "".join(val)
    if state == VALUE:
        value = value.rstrip(" \t\n\r\f\v")
    value = value.rstrip(" \t\n\r\f\v")          # strdtb
    if len(value) >= 2 and value[0] in "'\"" and value[-1] == value[0]:
        value = value[1:-1]
    nm = "".join(name)
    if len(nm) + 1 + len(value) >= MAX_ENVSTR - 1:
        return False, envstr
    return True, f"{nm}={value}"


def _get_number(f: _Stream, low: int, names, ch):
    temp = []
    all_digits = True
    while _isalnum(ch):
        if len(temp) + 1 >= MAX_TEMPSTR:
            return EOF, 0
        temp.append(ch)
        if not ch.isdigit():
            all_digits = False
        ch = f.get()
    if not temp:
        return EOF, 0
    word = "".join(temp)
    if names:
        for i, nm in enumerate(names):
            if nm.lower() == word.lower():
                return ch, i + low
    if all_digits:
        return ch, int(word)
    return EOF, 0


def _get_range(f: _Stream, bits: set, low: int, high: int, names, ch, warn):
    if ch == "*":
        lo, hi = low, high
        ch = f.get()
        if ch == EOF:
            return EOF
    else:
        ch, lo = _get_number(f, low, names, ch)
        if ch == EOF:
            return EOF
        if ch != "-":
            if ch == "/":             # "5/10": step without a range is unsupported
                return EOF
            if lo < low or lo > high:
                return EOF
            bits.add(lo)
            return ch
        ch = f.get()
        if ch == EOF:
            return EOF
        ch, hi = _get_number(f, low, names, ch)
        if ch == EOF:
            return EOF
    if ch == "/":
        ch = f.get()
        if ch == EOF:
            return EOF
        ch, step = _get_number(f, 0, None, ch)
        if ch == EOF or step <= 0:
            return EOF
    else:
        step = 1
    if lo < low or lo > high or hi < low or hi > high:
        return EOF
    if step > 1 and step > (hi - lo):
        mx = hi - lo if hi - lo > 0 else 1
        warn(f"Warning: Step size {step} higher than possible maximum of {mx}")
    i = lo
    while i <= hi:
        bits.add(i)
        i += step
    return ch


def _get_list(f: _Stream, bits: set, low: int, high: int, names, ch, warn):
    bits.clear()
    while True:
        ch = _get_range(f, bits, low, high, names, ch, warn)
        if ch == ",":
            ch = f.get()
        else:
            break
    while ch != EOF and ch not in (" ", "\t", "\n"):   # Skip_Nonblanks
        ch = f.get()
    while ch in (" ", "\t"):                           # Skip_Blanks
        ch = f.get()
    return ch


# ─── entries ────────────────────────────────────────────────────────────────

@dataclass
class Entry:
    """One job line of a crontab."""
    minute: frozenset
    hour: frozenset
    dom: frozenset
    month: frozenset
    dow: frozenset          # 0..7, Sunday is both 0 and 7
    dom_star: bool
    dow_star: bool
    command: str            # the raw command text, % and all (as written)
    lineno: int             # 1-based line in the file
    line: str               # the full physical line
    user: str | None = None  # system crontabs (/etc/crontab, cron.d) only
    env: dict = field(default_factory=dict)  # NAME=value lines seen before this entry
    reboot: bool = False
    source: str = ""
    schedule: str = ""      # the time part as written, e.g. '*/5 * * * *' or '@daily'

    def matches(self, when: _dt.datetime) -> bool:
        """True if cron would start this job at that minute (seconds ignored)."""
        if self.reboot:
            return False
        dow = (when.weekday() + 1) % 7     # Monday=1 .. Sunday=0
        if when.minute not in self.minute or when.hour not in self.hour or when.month not in self.month:
            return False
        if self.dom_star or self.dow_star:
            return when.day in self.dom and dow in self.dow
        return when.day in self.dom or dow in self.dow

    def split(self):
        """(command, stdin_text or None) as cron would run it (see split_command)."""
        return split_command(self.command)


def _load_entry(f: _Stream, error, system: bool, env: dict, warn):
    ecode = E_NONE
    _skip_comments(f)
    start_line = f.line
    start_pos = f.pos
    ch = f.get()
    if ch == EOF:
        return None, True
    minute, hour, dom, month, dow = set(), set(), set(), set(), set()
    dom_star = dow_star = reboot = False
    user = None
    cmd = ""

    def fail(code, ch):
        if code != E_NONE:
            error(ECODES[code], f.line)
        while ch != EOF and ch != "\n":
            ch = f.get()
        return None, False

    if ch == "@":
        ch, word = f.get_string(" \t\n", MAX_COMMAND)
        if word == "reboot":
            reboot = True
        elif word in ("yearly", "annually"):
            minute, hour, dom, month = {0}, {0}, {1}, {1}
            dow = set(range(0, 8))
            dow_star = True
        elif word == "monthly":
            minute, hour, dom = {0}, {0}, {1}
            month = set(range(1, 13))
            dow = set(range(0, 8))
            dow_star = True
        elif word == "weekly":
            minute, hour = {0}, {0}
            dom = set(range(1, 32))
            dom_star = True
            month = set(range(1, 13))
            dow = {0}
        elif word in ("daily", "midnight"):
            minute, hour = {0}, {0}
            dom, month, dow = set(range(1, 32)), set(range(1, 13)), set(range(0, 8))
        elif word == "hourly":
            minute = {0}
            hour, dom, month, dow = set(range(24)), set(range(1, 32)), set(range(1, 13)), set(range(0, 8))
        else:
            return fail(E_TIMESPEC, ch)
    else:
        ch = _get_list(f, minute, FIRST_MINUTE, LAST_MINUTE, None, ch, warn)
        if ch == EOF:
            return fail(E_MINUTE, ch)
        ch = _get_list(f, hour, FIRST_HOUR, LAST_HOUR, None, ch, warn)
        if ch == EOF:
            return fail(E_HOUR, ch)
        if ch == "*":
            dom_star = True
        ch = _get_list(f, dom, FIRST_DOM, LAST_DOM, None, ch, warn)
        if ch == EOF:
            return fail(E_DOM, ch)
        ch = _get_list(f, month, FIRST_MONTH, LAST_MONTH, MONTH_NAMES, ch, warn)
        if ch == EOF:
            return fail(E_MONTH, ch)
        if ch == "*":
            dow_star = True
        ch = _get_list(f, dow, FIRST_DOW, LAST_DOW, DOW_NAMES, ch, warn)
        if ch == EOF:
            return fail(E_DOW, ch)
    if 0 in dow or 7 in dow:
        dow |= {0, 7}
    while ch in (" ", "\t"):
        ch = f.get()
    f.unget(ch)
    sched_end = f.pos
    if system:
        ch, user = f.get_string(" \t", MAX_COMMAND)
        if ch == EOF:
            return fail(E_CMD, ch)
        if not user or "\n" in user:
            return fail(E_USERNAME, ch)
    elif ch == "*":
        return fail(E_CMD, ch)
    ch, cmd = f.get_string("\n", MAX_COMMAND)
    if len(cmd) == MAX_COMMAND - 1:
        return fail(E_CMD_LEN, ch)
    if ch == EOF:
        return fail(E_CMD, ch)
    line_start = f.text.rfind("\n", 0, start_pos) + 1
    line = f.text[line_start:f.pos - 1]
    schedule = f.text[start_pos:sched_end].strip()
    return Entry(frozenset(minute), frozenset(hour), frozenset(dom), frozenset(month),
                 frozenset(dow), dom_star, dow_star, cmd, start_line, line, user,
                 dict(env), reboot, "", schedule), False


@dataclass
class Crontab:
    entries: list
    env: dict                  # every NAME=value line, last one wins
    errors: list               # crontab(1)-style messages, empty if fine
    warnings: list
    missing_newline: bool
    source: str = ""

    @property
    def ok(self) -> bool:
        return not self.errors and not self.missing_newline


def parse_crontab(text: str, system: bool = False, filename: str = "crontab",
                  source: str = "", first_line: int = 1) -> Crontab:
    """Parse a whole crontab the way crontab(1) checks it before installing.

    system=True for /etc/crontab and /etc/cron.d files (with a user field).
    Stops at the first error, like crontab(1). Entry line numbers are
    1-based physical lines (first_line is the number of the first line).
    """
    f = _Stream(text, first_line)
    entries, errors, warnings = [], [], []
    env: dict = {}
    missing_nl = False

    def error(msg, line):
        errors.append(f'"{filename}":{line - 1}: {msg}')

    while not errors and f.line < MAX_TAB_LINES + first_line + 1:
        status, envstr = _load_env(f)
        if status is None:
            if envstr:
                missing_nl = True
            break
        if status is True:
            k, _, v = envstr.partition("=")
            env[k] = v
            continue
        entry, at_eof = _load_entry(f, error, system, env, warnings.append)
        if entry is not None:
            entry.source = source
            entries.append(entry)
        elif at_eof:
            break
    if f.line >= MAX_TAB_LINES + first_line + 1:
        errors.append(f"crontab is too long; maximum number of lines is {MAX_TAB_LINES}.")
    return Crontab(entries, env, errors, warnings, missing_nl, source)


def check_install(text: str, filename: str, system: bool = False):
    """Messages crontab(1) prints before refusing to install, or [] if fine.

    The first lines are the per-line errors; the last line is the verdict.
    Step warnings are not included (see parse_crontab().warnings).
    """
    tab = parse_crontab(text, system=system, filename=filename)
    if tab.errors:
        if tab.errors[-1].startswith("crontab is too long"):
            return tab.errors
        return tab.errors + ["errors in crontab file, can't install."]
    if tab.missing_newline:
        return ["new crontab file is missing newline before EOF, can't install."]
    return []


def parse_line(line: str, system: bool = False) -> Entry:
    """Parse one job line; raises CronError if cron would reject it."""
    tab = parse_crontab(line.rstrip("\n") + "\n", system=system, filename="-")
    if tab.errors:
        raise CronError(tab.errors)
    if len(tab.entries) != 1:
        raise CronError([f"not a job line: {line.strip()!r}"])
    return tab.entries[0]


def split_command(cmd: str):
    """Apply cron's % rules: returns (command, stdin_text or None).

    Port of do_command.c: in the command, `\\%` -> `%` and `\\\\` -> `\\`; the
    first unescaped `%` ends it. In the input, `%` -> newline, `\\%` -> `%`,
    and a final newline is added if missing.
    """
    out = []
    escaped = False
    i = 0
    rest = None
    while i < len(cmd):
        ch = cmd[i]
        if escaped:
            if ch in ("%", "\\"):
                out[-1] = ch
            else:
                out.append(ch)
            escaped = False
            i += 1
            continue
        if ch == "\\":
            escaped = True
            out.append(ch)
            i += 1
            continue
        if ch == "%":
            rest = cmd[i + 1:]
            break
        out.append(ch)
        i += 1
    command = "".join(out)
    if not rest:
        return command, None
    data = []
    escaped = False
    need_newline = False
    for ch in rest:
        if escaped:
            if ch != "%":
                data.append("\\")
        elif ch == "%":
            ch = "\n"
        escaped = ch == "\\"
        if not escaped:
            data.append(ch)
            need_newline = ch != "\n"
    if escaped:
        data.append("\\")
    if need_newline:
        data.append("\n")
    return command, "".join(data)


# ─── header written by crontab(1) ───────────────────────────────────────────

def make_header(filename: str, when: _dt.datetime) -> str:
    stamp = when.strftime("%a %b ") + f"{when.day:2d}" + when.strftime(" %H:%M:%S %Y")
    return ("# DO NOT EDIT THIS FILE - edit the master and reinstall.\n"
            f"# ({filename} installed on {stamp:<24.24})\n"
            f"# (Cron version -- {RCSID})\n")


def strip_header(text: str) -> str:
    """What `crontab -l` shows: the first up to 3 lines are skipped while they are comments."""
    pos = 0
    for _ in range(NHEADER_LINES):
        if pos >= len(text):
            break
        if text[pos] != "#":
            break
        nl = text.find("\n", pos)
        if nl < 0:
            return ""
        pos = nl + 1
    return text[pos:]


# ─── time windows and expansion ─────────────────────────────────────────────

_TIME_FORMATS = ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M",
                 "%Y-%m-%d")


def parse_time(text: str) -> _dt.datetime:
    """'2024-04-08 14:30' (or with seconds, T separator, or a bare date)."""
    text = text.strip()
    if text == "now":
        return _dt.datetime.now().replace(second=0, microsecond=0)
    for fmt in _TIME_FORMATS:
        try:
            return _dt.datetime.strptime(text, fmt)
        except ValueError:
            pass
    raise ValueError(f"bad time {text!r}: use YYYY-MM-DD HH:MM")


def _days(start: _dt.date, end: _dt.date):
    d = start
    while d <= end:
        yield d
        d += _dt.timedelta(days=1)


def next_runs(entry: Entry, start: _dt.datetime, end: _dt.datetime):
    """Fire times of one entry in [start, end), in order."""
    if entry.reboot:
        return
    if start.second or start.microsecond:
        start = start.replace(second=0, microsecond=0) + _dt.timedelta(minutes=1)
    hours = sorted(entry.hour)
    minutes = sorted(entry.minute)
    if not hours or not minutes:
        return
    for day in _days(start.date(), end.date()):
        if day.month not in entry.month:
            continue
        dow = (day.weekday() + 1) % 7
        if entry.dom_star or entry.dow_star:
            ok = day.day in entry.dom and dow in entry.dow
        else:
            ok = day.day in entry.dom or dow in entry.dow
        if not ok:
            continue
        for h in hours:
            for m in minutes:
                t = _dt.datetime(day.year, day.month, day.day, h, m)
                if t < start:
                    continue
                if t >= end:
                    return
                yield t


def expand(entries, start: _dt.datetime, end: _dt.datetime):
    """All (time, entry) pairs in [start, end), ordered by time, then by entry order."""
    runs = []
    for idx, e in enumerate(entries):
        for t in next_runs(e, start, end):
            runs.append((t, idx, e))
    runs.sort(key=lambda r: (r[0], r[1]))
    return [(t, e) for t, _, e in runs]


# ─── file name rules ────────────────────────────────────────────────────────

_CLASSICAL = re.compile(r"^[a-zA-Z0-9_-]+$")
_LSB_HIER = re.compile(r"^_?([a-z0-9_.]+-)+[a-z0-9]+$")
_LSB_EXCL = re.compile(r"^[a-z0-9-].*dpkg-(old|dist|new|tmp)$")
_LSB_TRAD = re.compile(r"^[a-z0-9][a-z0-9-]*$")
_RP_TRAD = re.compile(r"^[a-z0-9][a-z0-9_-]*$")


def valid_crond_name(name: str, lsbsysinit: bool = False) -> bool:
    """Would cron read /etc/cron.d/<name>? (Debian cron, default mode: [A-Za-z0-9_-]+)."""
    if lsbsysinit:
        if _LSB_HIER.match(name):
            return not re.match(r"^[a-z0-9-].*dpkg-(old|dist)$", name)
        return bool(_LSB_TRAD.match(name))
    return bool(_CLASSICAL.match(name))


def valid_runparts_name(name: str, lsbsysinit: bool = False, regex: str | None = None) -> bool:
    """run-parts(8) name filter (debianutils)."""
    if regex is not None:
        return re.search(regex, name) is not None   # run-parts uses an extended regex, unanchored
    if lsbsysinit:
        # debianutils run-parts: LSB hierarchical names unless *.dpkg-{old,dist,new,tmp},
        # otherwise lower-case letters, digits, '_' and '-' (checked against the real one)
        if _LSB_HIER.match(name):
            return not _LSB_EXCL.match(name)
        return bool(_RP_TRAD.match(name))
    return bool(_CLASSICAL.match(name))


def run_parts_list(directory: str, lsbsysinit: bool = False, regex: str | None = None,
                   executable_only: bool = True, reverse: bool = False):
    """Paths run-parts would run in `directory`, in its order (C-locale sort)."""
    names = os.listdir(directory)
    names.sort(key=lambda n: n.encode("utf-8", "surrogateescape"), reverse=reverse)
    out = []
    for name in names:
        if not valid_runparts_name(name, lsbsysinit, regex):
            continue
        path = os.path.join(directory, name)
        try:
            st = os.stat(path)
        except OSError:
            continue
        if not _stat.S_ISREG(st.st_mode):
            continue
        if executable_only and not os.access(path, os.X_OK):
            continue
        out.append(path)
    return out


# ─── anacrontab ─────────────────────────────────────────────────────────────

_ANA_PERIOD_NAMES = {"@daily": 1, "@weekly": 7, "@monthly": 30, "@yearly": 365, "@annually": 365}


def parse_anacrontab(text: str):
    """Parse an anacrontab: returns (env dict, jobs list, errors list).

    Each job is a dict: period (days, int; @monthly = 30 here, anacron treats
    it as one calendar month), period_text, delay (minutes), job_id, command,
    lineno. Errors are 'line N: message' strings.
    """
    env, jobs, errors = {}, [], []
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$", line)
        if m and not re.match(r"^\S+\s+\d+\s+\S+\s", line):
            env[m.group(1)] = m.group(2)
            continue
        parts = line.split(None, 3)
        if len(parts) < 4:
            errors.append(f"line {n}: needs period, delay, job-identifier and command")
            continue
        period_text, delay, job_id, command = parts
        if period_text in _ANA_PERIOD_NAMES:
            period = _ANA_PERIOD_NAMES[period_text]
        elif period_text.isdigit():
            period = int(period_text)
        else:
            errors.append(f"line {n}: bad period {period_text!r}")
            continue
        if not delay.isdigit():
            errors.append(f"line {n}: bad delay {delay!r}")
            continue
        if "/" in job_id:
            errors.append(f"line {n}: job identifier may not contain '/'")
            continue
        if any(j["job_id"] == job_id for j in jobs):
            errors.append(f"line {n}: duplicate job identifier {job_id!r}")
            continue
        jobs.append({"period": period, "period_text": period_text, "delay": int(delay),
                     "job_id": job_id, "command": command, "lineno": n})
    return env, jobs, errors
