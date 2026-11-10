"""systemd OnCalendar= expressions (systemd.time(7)) for the LinuxMissions mocks.

A port of the parts of systemd's calendarspec.c that timer levels need:
parsing, the normalized form that `systemd-analyze calendar` prints, and the
next elapse times. Use it where the real `systemd-analyze` is missing (macOS);
the reference image has the real one and the unit tests compare the two.

Supported: weekday lists and ranges (`Mon..Fri`, also the old `Mon-Fri`),
`YYYY-MM-DD` / `MM-DD` dates with `*`, lists, `a..b` ranges and `/step`
repetitions, `~` (days from the end of the month, single values only),
`HH:MM[:SS]` times with the same syntax, the shorthands minutely hourly daily
weekly monthly yearly annually quarterly semiannually (and bi-annually
spellings), a trailing ` UTC` or IANA time zone, and `@EPOCH`.
Not supported (raises ValueError with "mock: ..."): `~` with ranges or
repetitions.
"""
from __future__ import annotations

import datetime as _dt
import re
import sys
import time as _time

try:
    import zoneinfo as _zoneinfo
except ImportError:  # pragma: no cover
    _zoneinfo = None

__all__ = ["CalendarSpec", "parse", "normalize", "next_elapse", "main"]

MIN_YEAR, MAX_YEAR = 1970, 2199
USEC = 1_000_000
USEC_MINUTE = 60 * USEC
BITS_WEEKDAYS = 127
_DAY_NR = [("Monday", 0), ("Mon", 0), ("Tuesday", 1), ("Tue", 1), ("Wednesday", 2), ("Wed", 2),
           ("Thursday", 3), ("Thu", 3), ("Friday", 4), ("Fri", 4), ("Saturday", 5), ("Sat", 5),
           ("Sunday", 6), ("Sun", 6)]
_DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


class _Comp:
    __slots__ = ("start", "stop", "repeat")

    def __init__(self, start, stop=-1, repeat=0):
        self.start, self.stop, self.repeat = start, stop, repeat

    def key(self):
        return (self.start, self.stop, self.repeat)


class CalendarSpec:
    def __init__(self):
        self.weekdays_bits = -1
        self.end_of_month = False
        self.utc = False
        self.timezone = None
        self.year = None     # None = '*'
        self.month = None
        self.day = None
        self.hour = None
        self.minute = None
        self.second = None   # in microseconds, like systemd
        self.original = ""

    # ── output ──
    def normalized(self) -> str:
        out = []
        if 0 < self.weekdays_bits <= BITS_WEEKDAYS:
            out.append(_format_weekdays(self.weekdays_bits) + " ")
        out.append(_format_chain(self.year, 4))
        out.append("-")
        out.append(_format_chain(self.month, 2))
        out.append("~" if self.end_of_month else "-")
        out.append(_format_chain(self.day, 2))
        out.append(" ")
        out.append(_format_chain(self.hour, 2))
        out.append(":")
        out.append(_format_chain(self.minute, 2))
        out.append(":")
        out.append(_format_chain(self.second, 2, usec=True))
        if self.utc:
            out.append(" UTC")
        elif self.timezone:
            out.append(" " + self.timezone)
        return "".join(out)

    __str__ = normalized

    # ── matching ──
    def _values(self, chain, lo, hi, dim=None):
        if chain is None:
            return list(range(lo, hi + 1))
        vals = set()
        for c in chain:
            start, stop = c.start, c.stop
            if dim is not None:     # end of month: count back from the last day
                start = dim - start + 1
                stop = dim - stop + 1 if stop >= 0 else -1
                if stop >= 0:
                    start, stop = min(start, stop), max(start, stop)
            if c.repeat > 0:
                v = start
                end = stop if stop >= 0 else hi
                while v <= end and v <= hi:
                    if v >= lo:
                        vals.add(v)
                    v += c.repeat
            elif stop >= 0:
                vals.update(range(max(start, lo), min(stop, hi) + 1))
            elif lo <= start <= hi:
                vals.add(start)
        return sorted(vals)

    def _zone(self):
        if self.utc:
            return _dt.timezone.utc
        if self.timezone and _zoneinfo is not None:
            return _zoneinfo.ZoneInfo(self.timezone)
        return None

    def next_after(self, when: _dt.datetime) -> _dt.datetime | None:
        """First elapse strictly after `when` (aware datetime, or naive = local time).

        Returns an aware datetime in the local time zone, or None.
        """
        if when.tzinfo is None:
            when = when.astimezone()
        zone = self._zone()
        base = when.astimezone(zone) if zone else when.astimezone()
        after = base.replace(tzinfo=None)   # strictly later than this wall time
        years = self._values(self.year, MIN_YEAR, MAX_YEAR)
        hours = self._values(self.hour, 0, 23)
        minutes = self._values(self.minute, 0, 59)
        seconds = self._values(self.second, 0, USEC_MINUTE - 1)
        if not hours or not minutes or not seconds:
            return None
        for y in years:
            if y < after.year:
                continue
            for m in self._values(self.month, 1, 12):
                if (y, m) < (after.year, after.month):
                    continue
                dim = _days_in_month(y, m)
                days = self._values(self.day, 1, 31, dim if self.end_of_month else None)
                for d in days:
                    if d > dim:
                        continue
                    date = _dt.date(y, m, d)
                    if date < after.date():
                        continue
                    if 0 < self.weekdays_bits <= BITS_WEEKDAYS and not (self.weekdays_bits >> date.weekday()) & 1:
                        continue
                    for h in hours:
                        for mi in minutes:
                            for s in seconds:
                                cand = _dt.datetime(y, m, d, h, mi, s // USEC, s % USEC)
                                if cand <= after:
                                    continue
                                if zone is not None:
                                    aware = cand.replace(tzinfo=zone)
                                else:
                                    aware = _local_aware(cand)
                                    if aware is None:
                                        continue
                                return aware.astimezone()
        return None

    def iterate(self, when: _dt.datetime, n: int):
        out = []
        cur = when
        for _ in range(n):
            nxt = self.next_after(cur)
            if nxt is None:
                break
            out.append(nxt)
            cur = nxt
        return out


def _local_aware(naive: _dt.datetime):
    """Naive local wall time -> aware; None if it does not exist (DST gap)."""
    try:
        epoch = _time.mktime(naive.replace(microsecond=0).timetuple())
    except (OverflowError, ValueError):
        return None
    aware = _dt.datetime.fromtimestamp(epoch).astimezone().replace(microsecond=naive.microsecond)
    if aware.replace(tzinfo=None) != naive:
        return None
    return aware


def _days_in_month(y, m):
    if m == 12:
        return 31
    return (_dt.date(y, m + 1, 1) - _dt.date(y, m, 1)).days


def _format_weekdays(bits: int) -> str:
    out = []
    need_comma = False
    l = -1
    x = 0
    for x in range(7):
        if bits & (1 << x):
            if l < 0:
                if need_comma:
                    out.append(",")
                else:
                    need_comma = True
                out.append(_DAYS[x])
                l = x
        elif l >= 0:
            if x > l + 1:
                out.append(".." if x > l + 2 else ",")
                out.append(_DAYS[x - 1])
            l = -1
    x = 7
    if l >= 0 and x > l + 1:
        out.append(".." if x > l + 2 else ",")
        out.append(_DAYS[x - 1])
    return "".join(out)


def _format_chain(chain, width: int, usec: bool = False) -> str:
    d = USEC if usec else 1
    if chain is None:
        return "*"
    if usec and len(chain) == 1 and chain[0].start == 0 and chain[0].repeat == USEC:
        return "*"
    parts = []
    for c in chain:
        s = f"{c.start // d:0{width}d}"
        if c.start % d > 0:
            s += f".{c.start % d:06d}"
        if c.stop > 0:
            s += f"..{c.stop // d:0{width}d}"
            if c.stop % d > 0:
                s += f".{c.stop % d:06d}"
        if c.repeat > 0 and not (c.stop > 0 and c.repeat == d):
            s += f"/{c.repeat // d}"
            if c.repeat % d > 0:
                s += f".{c.repeat % d:06d}"
        parts.append(s)
    return ",".join(parts)


# ─── parser (port of calendarspec.c) ────────────────────────────────────────

class _P:
    def __init__(self, s):
        self.s = s
        self.i = 0

    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if j < len(self.s) else ""

    def skip_spaces(self):
        while self.peek() == " ":
            self.i += 1


def _bad(msg="Invalid argument"):
    return ValueError(msg)


def _parse_weekdays(p: _P, c: CalendarSpec):
    l = -1
    first = True
    while True:
        rest = p.s[p.i:]
        found = None
        for name, nr in _DAY_NR:
            if rest[: len(name)].lower() == name.lower():
                nxt = rest[len(name): len(name) + 1]
                if nxt not in ("", "-", ".", ",", " "):
                    raise _bad()
                found = (name, nr)
                break
        if found is None:
            if first:
                return
            raise _bad()
        name, nr = found
        if c.weekdays_bits < 0:
            c.weekdays_bits = 0
        c.weekdays_bits |= 1 << nr
        if l >= 0:
            if l > nr:
                raise _bad()
            for j in range(l + 1, nr):
                c.weekdays_bits |= 1 << j
        p.i += len(name)
        if p.peek() == "":
            return
        if p.peek() == " ":
            p.skip_spaces()
            return
        if p.peek() == ".":
            if l >= 0 or p.peek(1) != ".":
                raise _bad()
            l = nr
            p.i += 2
        elif p.peek() == "-":
            if l >= 0:
                raise _bad()
            l = nr
            p.i += 1
        elif p.peek() == ",":
            l = -1
            p.i += 1
        if p.peek() in ("", " "):
            p.skip_spaces()
            if l >= 0:
                raise _bad()
            return
        first = False


def _parse_decimal(p: _P, usec: bool):
    m = re.match(r"\d+", p.s[p.i:])
    if not m:
        raise _bad()
    p.i += m.end()
    value = int(m.group(0))
    if usec:
        value *= USEC
        if p.peek() == ".":
            frac = re.match(r"\.(\d*)", p.s[p.i:])
            p.i += frac.end()
            digits = (frac.group(1) + "000000")[:6]
            value += int(digits)
    return value


def _parse_chain(p: _P, usec: bool):
    """Returns (chain or None for '*', star_for_seconds)."""
    if p.peek() == "*":
        p.i += 1
        if usec:
            return [_Comp(0, -1, USEC)], False
        return None, False
    chain = []
    while True:
        start = _parse_decimal(p, usec)
        stop, repeat = -1, 0
        if p.peek() == "." and p.peek(1) == ".":
            p.i += 2
            stop = _parse_decimal(p, usec)
            repeat = USEC if usec else 1
        if p.peek() == "/":
            p.i += 1
            repeat = _parse_decimal(p, usec)
            if repeat == 0:
                raise _bad("Numerical result out of range")
        else:
            if usec and stop >= 0 and start + repeat > stop:
                raise _bad()
        if p.peek() not in ("", " ", ",", "-", "~", ":"):
            raise _bad()
        chain.append(_Comp(start, stop, repeat))
        if p.peek() != ",":
            break
        p.i += 1
    return chain, False


def _parse_date(p: _P, c: CalendarSpec):
    if p.peek() == "":
        return
    if p.peek() == "@":
        raise _bad("mock: '@EPOCH' handled before parsing")
    save = p.i
    first, _ = _parse_chain(p, False)
    if p.peek() in ("", ":"):
        p.i = save
        return
    if p.peek() == "~":
        c.end_of_month = True
    elif p.peek() != "-":
        raise _bad()
    p.i += 1
    second, _ = _parse_chain(p, False)
    if p.peek() in ("", " "):
        p.skip_spaces()
        c.month, c.day = first, second
        return
    if c.end_of_month:
        raise _bad()
    if p.peek() == "~":
        c.end_of_month = True
    elif p.peek() != "-":
        raise _bad()
    p.i += 1
    third, _ = _parse_chain(p, False)
    if p.peek() not in ("", " "):
        raise _bad()
    p.skip_spaces()
    c.year, c.month, c.day = first, second, third


def _parse_time(p: _P, c: CalendarSpec):
    if p.peek() == "":
        c.hour, c.minute, c.second = [_Comp(0)], [_Comp(0)], [_Comp(0)]
        return
    h, _ = _parse_chain(p, False)
    if p.peek() != ":":
        raise _bad()
    p.i += 1
    m, _ = _parse_chain(p, False)
    if p.peek() == "":
        c.hour, c.minute, c.second = h, m, [_Comp(0)]
        return
    if p.peek() != ":":
        raise _bad()
    p.i += 1
    s, _ = _parse_chain(p, True)
    if p.peek() != "":
        raise _bad()
    c.hour, c.minute, c.second = h, m, s


def _const(v):
    return [_Comp(v)]


def _normalize_chain(chain):
    if chain is None:
        return None
    for i in chain:
        if i.stop > i.start and i.repeat > 0:
            i.stop -= (i.stop - i.start) % i.repeat
        if (i.stop > i.start and i.stop < i.start + i.repeat) or i.stop == i.start:
            i.repeat = 0
            i.stop = -1
    uniq = {}
    for i in chain:
        uniq.setdefault(i.key(), i)
    return [uniq[k] for k in sorted(uniq)]


def _chain_valid(chain, lo, hi, end_of_month=False):
    if chain is None:
        return True
    for c in chain:
        if c.start < lo or c.start > hi:
            return False
        if c.repeat > hi - lo:
            return False
        if c.stop >= 0:
            if c.stop < lo or c.stop > hi:
                return False
            if not end_of_month and c.start > c.stop:
                return False
    return True


_SHORTHANDS = {
    "minutely": ("*", "*", "*", "*", "*", "0"),
    "hourly": ("*", "*", "*", "*", "00", "00"),
    "daily": ("*", "*", "*", "00", "00", "00"),
    "monthly": ("*", "*", "01", "00", "00", "00"),
    "weekly": ("*", "*", "*", "00", "00", "00"),
    "yearly": ("*", "01", "01", "00", "00", "00"),
    "annually": ("*", "01", "01", "00", "00", "00"),
    "quarterly": ("*", "01,04,07,10", "01", "00", "00", "00"),
    "semiannually": ("*", "01,07", "01", "00", "00", "00"),
    "semi-annually": ("*", "01,07", "01", "00", "00", "00"),
    "biannually": ("*", "01,07", "01", "00", "00", "00"),
    "bi-annually": ("*", "01,07", "01", "00", "00", "00"),
}


def parse(text: str) -> CalendarSpec:
    """Parse an OnCalendar= value; raises ValueError like systemd (-EINVAL)."""
    c = CalendarSpec()
    c.original = text
    s = text
    if s.upper().endswith(" UTC"):
        c.utc = True
        s = s[:-4]
    else:
        last = s.rsplit(" ", 1)
        if len(last) == 2 and last[1] and _zoneinfo is not None and "/" in last[1]:
            try:
                _zoneinfo.ZoneInfo(last[1])
                c.timezone = last[1]
                s = last[0]
            except Exception:
                pass
    if not s:
        raise _bad()
    low = s.lower()
    if low in _SHORTHANDS:
        y, mo, d, h, mi, se = _SHORTHANDS[low]
        conv = lambda v: None if v == "*" else [_Comp(int(x)) for x in v.split(",")]  # noqa: E731
        c.year, c.month, c.day, c.hour, c.minute = conv(y), conv(mo), conv(d), conv(h), conv(mi)
        c.second = [_Comp(0)]
        if low == "weekly":
            c.weekdays_bits = 1
    elif s.startswith("@"):
        if not re.fullmatch(r"@\d+", s):
            raise _bad()
        t = _dt.datetime.fromtimestamp(int(s[1:]), _dt.timezone.utc)
        c.utc = True
        c.year, c.month, c.day = _const(t.year), _const(t.month), _const(t.day)
        c.hour, c.minute, c.second = _const(t.hour), _const(t.minute), _const(t.second * USEC)
    else:
        p = _P(s)
        _parse_weekdays(p, c)
        _parse_date(p, c)
        _parse_time(p, c)
        if p.peek() != "":
            raise _bad()
        if c.end_of_month and c.day:
            for comp in c.day:
                if comp.stop >= 0 or comp.repeat > 0:
                    raise _bad("mock: '~' with a range or repetition is not supported")
    # normalize
    if c.weekdays_bits <= 0 or c.weekdays_bits >= BITS_WEEKDAYS:
        c.weekdays_bits = -1
    if c.end_of_month and not c.day:
        c.end_of_month = False
    if c.year:
        for comp in c.year:
            for attr in ("start", "stop"):
                v = getattr(comp, attr)
                if 0 <= v < 70:
                    setattr(comp, attr, v + 2000)
                elif 70 <= v < 100:
                    setattr(comp, attr, v + 1900)
    c.year = _normalize_chain(c.year)
    c.month = _normalize_chain(c.month)
    c.day = _normalize_chain(c.day)
    c.hour = _normalize_chain(c.hour)
    c.minute = _normalize_chain(c.minute)
    c.second = _normalize_chain(c.second)
    if not (_chain_valid(c.year, MIN_YEAR, MAX_YEAR) and _chain_valid(c.month, 1, 12)
            and _chain_valid(c.day, 1, 31, c.end_of_month) and _chain_valid(c.hour, 0, 23)
            and _chain_valid(c.minute, 0, 59) and _chain_valid(c.second, 0, USEC_MINUTE - 1)):
        raise _bad()
    return c


def normalize(text: str) -> str:
    """The 'Normalized form' line of `systemd-analyze calendar TEXT`."""
    return parse(text).normalized()


def next_elapse(text: str, after: _dt.datetime | None = None, n: int = 1):
    """The next n elapse times (aware, local zone) strictly after `after` (default now)."""
    spec = parse(text)
    return spec.iterate(after or _dt.datetime.now().astimezone(), n)


# ─── systemd-analyze calendar output ────────────────────────────────────────

_USEC_YEAR = 31557600
_USEC_MONTH = 2629800
_WEEK, _DAY, _HOUR, _MIN = 604800, 86400, 3600, 60


def _plural(n, word):
    return f"{n} {word}{'' if n == 1 else 's'}"


def format_relative(seconds: float) -> str:
    """systemd's format_timestamp_relative() for a difference in seconds."""
    if seconds > 0:
        d, suffix = seconds, "left"
    elif seconds < 0:
        d, suffix = -seconds, "ago"
    else:
        return "now"
    d = int(d)
    if d >= _USEC_YEAR:
        y = d // _USEC_YEAR
        mo = (d % _USEC_YEAR) // _USEC_MONTH
        return f"{_plural(y, 'year')} {_plural(mo, 'month')} {suffix}"
    if d >= _USEC_MONTH:
        mo = d // _USEC_MONTH
        days = (d % _USEC_MONTH) // _DAY
        return f"{_plural(mo, 'month')} {_plural(days, 'day')} {suffix}"
    if d >= _WEEK:
        w = d // _WEEK
        days = (d % _WEEK) // _DAY
        return f"{_plural(w, 'week')} {_plural(days, 'day')} {suffix}"
    if d >= 2 * _DAY:
        return f"{d // _DAY} days {suffix}"
    if d >= 25 * _HOUR:
        return f"1 day {(d - _DAY) // _HOUR}h {suffix}"
    if d >= 6 * _HOUR:
        return f"{d // _HOUR}h {suffix}"
    if d >= _HOUR:
        return f"{d // _HOUR}h {(d % _HOUR) // _MIN}min {suffix}"
    if d >= 5 * _MIN:
        return f"{d // _MIN}min {suffix}"
    if d >= _MIN:
        return f"{d // _MIN}min {d % _MIN}s {suffix}"
    return f"{d}s {suffix}"


def _fmt_ts(t: _dt.datetime) -> str:
    return t.strftime("%a %Y-%m-%d %H:%M:%S ") + (t.tzname() or "")


def _parse_base(text: str) -> _dt.datetime:
    text = text.strip()
    if text == "now":
        return _dt.datetime.now().astimezone()
    if text.startswith("@") and text[1:].isdigit():
        return _dt.datetime.fromtimestamp(int(text[1:])).astimezone()
    utc = False
    if text.upper().endswith(" UTC"):
        utc, text = True, text[:-4]
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d", "%Y-%m-%dT%H:%M:%S"):
        try:
            t = _dt.datetime.strptime(text, fmt)
        except ValueError:
            continue
        return t.replace(tzinfo=_dt.timezone.utc) if utc else t.astimezone()
    raise ValueError(text)


def calendar_report(specs, iterations=1, base=None, now=None, out=sys.stdout, err=sys.stderr) -> int:
    """Print what `systemd-analyze calendar` prints; returns its exit status."""
    now = now or _dt.datetime.now().astimezone()
    base = base or now
    rc = 0
    local_is_utc = now.utcoffset() == _dt.timedelta(0)
    for idx, text in enumerate(specs):
        try:
            spec = parse(text)
        except ValueError as exc:
            msg = str(exc)
            if msg.startswith("mock:"):
                print(f"Failed to parse calendar specification '{text}': {msg}", file=err)
            else:
                print(f"Failed to parse calendar specification '{text}': {msg}", file=err)
            rc = 1
            if idx + 1 < len(specs):
                print(file=out)
            continue
        norm = spec.normalized()
        if norm != text:
            print(f"  Original form: {text}", file=out)
        print(f"Normalized form: {norm}", file=out)
        times = spec.iterate(base, iterations)
        if not times:
            print("    Next elapse: never", file=out)
        for i, t in enumerate(times):
            label = "    Next elapse" if i == 0 else f"   Iteration #{i + 1}"
            print(f"{label}: {_fmt_ts(t)}", file=out)
            if not local_is_utc:
                print(f"       (in UTC): {_fmt_ts(t.astimezone(_dt.timezone.utc))}", file=out)
            print(f"       From now: {format_relative((t - now).total_seconds())}", file=out)
        if idx + 1 < len(specs):
            print(file=out)
    return rc


def main(argv=None) -> int:
    """`systemd-analyze calendar [--iterations=N] [--base-time=TIME] SPEC...` (mock)."""
    argv = list(sys.argv[1:] if argv is None else argv)
    iterations, base, specs, verb = 1, None, [], None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a.startswith("--iterations"):
            val = a.split("=", 1)[1] if "=" in a else (argv[i + 1] if i + 1 < len(argv) else "")
            if "=" not in a:
                i += 1
            if not val.isdigit():
                print(f"Failed to parse --iterations= argument: {val}", file=sys.stderr)
                return 1
            iterations = int(val)
        elif a.startswith("--base-time"):
            val = a.split("=", 1)[1] if "=" in a else (argv[i + 1] if i + 1 < len(argv) else "")
            if "=" not in a:
                i += 1
            try:
                base = _parse_base(val)
            except ValueError:
                print(f"Failed to parse --base-time= parameter: {val}", file=sys.stderr)
                return 1
        elif a in ("-h", "--help"):
            print("systemd-analyze [OPTIONS...] calendar SPEC...\n\n"
                  "LinuxMissions mock: only the 'calendar' verb is supported,\n"
                  "with --iterations=N and --base-time=TIME.")
            return 0
        elif a == "--":
            specs.extend(argv[i + 1:])
            break
        elif a.startswith("-") and verb is None:
            print(f"mock: systemd-analyze option {a} not supported", file=sys.stderr)
            return 1
        elif verb is None:
            verb = a
        else:
            specs.append(a)
        i += 1
    if verb is None:
        print("mock: systemd-analyze without a verb is not supported (try: calendar SPEC)", file=sys.stderr)
        return 1
    if verb != "calendar":
        print(f"mock: systemd-analyze {verb} not supported (only 'calendar')", file=sys.stderr)
        return 1
    if not specs:
        print("Too few arguments.", file=sys.stderr)
        return 1
    return calendar_report(specs, iterations, base)


if __name__ == "__main__":
    sys.exit(main())
