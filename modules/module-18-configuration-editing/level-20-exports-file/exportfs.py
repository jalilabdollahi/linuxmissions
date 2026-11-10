#!/usr/bin/env python3
"""Level-local stand-in for exportfs(8), working on etc/exports and etc/exports.d/*.exports of
the sandbox that holds this bin/ directory. The "kernel table" is var/lib/nfs/etab.
Supported: exportfs [-v] [-r] [-a] (any combination). Paths such as /srv/builds are looked up
below the sandbox. Warnings and errors follow nfs-utils' wording."""
import os, re, sys

ROOT = os.environ.get("LM_ROOT") or os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
EXPORTS = os.path.join(ROOT, "etc/exports")
EXPORTS_D = os.path.join(ROOT, "etc/exports.d")
ETAB = os.path.join(ROOT, "var/lib/nfs/etab")
KNOWN = {"ro", "rw", "sync", "async", "wdelay", "no_wdelay", "hide", "nohide", "subtree_check",
         "no_subtree_check", "secure", "insecure", "root_squash", "no_root_squash", "all_squash",
         "no_all_squash", "crossmnt", "mountpoint", "mp", "fsid", "anonuid", "anongid", "sec",
         "no_acl", "secure_locks", "insecure_locks", "pnfs", "no_pnfs"}


def logical_lines(path):
    buf, start = "", 0
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        if not buf:
            start = n
        line = raw.rstrip()
        if line.endswith("\\"):
            buf += line[:-1]
            continue
        buf += line
        if buf.strip() and not buf.lstrip().startswith("#"):
            yield start, buf
        buf = ""


def verbose_options(opts):
    o = {}
    for item in opts:
        k, _, v = item.partition("=")
        o[k] = v
    out = []
    out.append("async" if "async" in o else "sync")
    if "async" not in o and "no_wdelay" not in o:
        out.append("wdelay")
    out.append("nohide" if "nohide" in o else "hide")
    if "subtree_check" not in o:
        out.append("no_subtree_check")
    out.append("sec=" + (o.get("sec") or "sys"))
    out.append("rw" if "rw" in o else "ro")
    out.append("insecure" if "insecure" in o else "secure")
    out.append("no_root_squash" if "no_root_squash" in o else "root_squash")
    out.append("all_squash" if "all_squash" in o else "no_all_squash")
    for k in ("anonuid", "anongid", "fsid"):
        if k in o:
            out.append(f"{k}={o[k]}")
    return ",".join(out)


def load(verbose, messages):
    """Return [(path, client, verbose_options)] in file order; print warnings like exportfs."""
    files = [EXPORTS]
    if os.path.isdir(EXPORTS_D):
        files += [os.path.join(EXPORTS_D, f) for f in sorted(os.listdir(EXPORTS_D)) if f.endswith(".exports")]
    result = []
    for path in files:
        if not os.path.isfile(path):
            continue
        shown = "/" + os.path.relpath(path, ROOT)
        for n, text in logical_lines(path):
            toks = text.split()
            exp, specs = toks[0], toks[1:]
            if not specs:
                specs = ["*"]
            real = os.path.join(ROOT, exp.lstrip("/"))
            if not os.path.isdir(real):
                messages.append(f"exportfs: Failed to stat {exp}: No such file or directory")
                continue
            for spec in specs:
                m = re.match(r"^([^(]*)(?:\((.*)\))?$", spec)
                client = m.group(1) or "*"
                opts = [x for x in (m.group(2) or "").split(",") if x]
                bad = [x for x in opts if x.partition("=")[0] not in KNOWN]
                if bad:
                    messages.append(f'exportfs: {shown} [{n}]: Unknown keyword "{bad[0]}"')
                    continue
                keys = {x.partition("=")[0] for x in opts}
                if "sync" not in keys and "async" not in keys:
                    messages.append(f'exportfs: {shown} [{n}]: No \'sync\' or \'async\' option specified for export "{client}:{exp}".\n'
                                    "  Assuming default behaviour ('sync').\n"
                                    "  NOTE: this default has changed from previous versions")
                if "subtree_check" not in keys and "no_subtree_check" not in keys:
                    messages.append(f'exportfs: {shown} [{n}]: Neither \'subtree_check\' or \'no_subtree_check\' specified for export "{client}:{exp}".\n'
                                    "  Assuming default behaviour ('no_subtree_check').\n"
                                    "  NOTE: this default has changed since nfs-utils version 1.0.x")
                result.append((exp, client, verbose_options(opts)))
    return result


def read_etab():
    if not os.path.isfile(ETAB):
        return []
    return [tuple(l.split("\t")) for l in open(ETAB).read().splitlines() if l]


def show(entries, verbose):
    last = None
    for path, client, opts in entries:
        c = "<world>" if client == "*" else client
        text = f"{c}({opts})" if verbose else c
        if len(path) > 14:
            print(path)
            print("\t\t" + text)
        else:
            print(f"{path:<14}\t{text}")


def main():
    flags = set()
    for a in sys.argv[1:]:
        if a.startswith("-") and not a.startswith("--") and len(a) > 1:
            for ch in a[1:]:
                if ch not in "vra":
                    print(f"exportfs: mock: option -{ch} is not supported", file=sys.stderr)
                    return 1
                flags.add(ch)
        else:
            print(f"exportfs: mock: argument {a} is not supported", file=sys.stderr)
            return 1
    if flags & {"r", "a"}:
        msgs = []
        entries = load("v" in flags, msgs)
        for m in msgs:
            print(m, file=sys.stderr)
        merged = entries if "r" in flags else read_etab() + [e for e in entries if e not in read_etab()]
        if "v" in flags:
            for path, client, _ in entries:
                print(f"exporting {'*' if client == '*' else client}:{path}")
        os.makedirs(os.path.dirname(ETAB), exist_ok=True)
        with open(ETAB, "w") as f:
            for e in merged:
                f.write("\t".join(e) + "\n")
        return 0
    show(read_etab(), "v" in flags)
    return 0


sys.exit(main())
