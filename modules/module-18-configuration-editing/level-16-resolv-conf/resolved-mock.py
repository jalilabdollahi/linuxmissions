#!/usr/bin/env python3
"""Level-local stand-in for systemd-resolved: `systemctl restart systemd-resolved`
regenerates the run/systemd/resolve/*.conf files from etc/systemd/resolved.conf and its
drop-ins; `resolvectl status` shows what was last generated. The first argument is the tool name
(systemctl or resolvectl), passed by the wrappers in bin/."""
import os, sys

ROOT = os.environ.get("LM_ROOT") or os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
CONF = os.path.join(ROOT, "etc/systemd/resolved.conf")
DROPINS = os.path.join(ROOT, "etc/systemd/resolved.conf.d")
RUN = os.path.join(ROOT, "run/systemd/resolve")
LISTS = ("DNS", "Domains", "FallbackDNS")


def load():
    """Same rules as systemd: files in order, list settings accumulate, an empty
    assignment resets the list, keys outside [Resolve] are ignored with a warning."""
    files = [CONF]
    if os.path.isdir(DROPINS):
        files += [os.path.join(DROPINS, f) for f in sorted(os.listdir(DROPINS)) if f.endswith(".conf")]
    cfg = {k: [] for k in LISTS}
    warnings = []
    for path in files:
        if not os.path.isfile(path):
            continue
        section = None
        for n, raw in enumerate(open(path).read().splitlines(), 1):
            line = raw.strip()
            if not line or line[0] in "#;":
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1]
                continue
            if "=" not in line:
                warnings.append(f"{path}:{n}: Missing '=', ignoring line.")
                continue
            if section != "Resolve":
                warnings.append(f"{path}:{n}: Assignment outside of section. Ignoring.")
                continue
            key, val = (s.strip() for s in line.split("=", 1))
            if key in LISTS:
                cfg[key] = [] if not val else cfg[key] + val.split()
            else:
                cfg[key] = val
    return cfg, warnings


def restart():
    cfg, warnings = load()
    for w in warnings:
        print(w, file=sys.stderr)
    os.makedirs(RUN, exist_ok=True)
    search = " ".join(cfg["Domains"])
    stub = ["# This is /run/systemd/resolve/stub-resolv.conf managed by man:systemd-resolved(8).",
            "# Do not edit.", "nameserver 127.0.0.53", "options edns0 trust-ad"]
    if search:
        stub.append("search " + search)
    up = ["# This is /run/systemd/resolve/resolv.conf managed by man:systemd-resolved(8).",
          "# Do not edit."] + [f"nameserver {s}" for s in cfg["DNS"]]
    if search:
        up.append("search " + search)
    open(os.path.join(RUN, "stub-resolv.conf"), "w").write("\n".join(stub) + "\n")
    open(os.path.join(RUN, "resolv.conf"), "w").write("\n".join(up) + "\n")


def status():
    servers, domains = [], []
    p = os.path.join(RUN, "resolv.conf")
    if os.path.isfile(p):
        for line in open(p):
            f = line.split()
            if len(f) >= 2 and f[0] == "nameserver":
                servers.append(f[1])
            elif len(f) >= 2 and f[0] == "search":
                domains = f[1:]
    print("Global")
    print("       Protocols: +LLMNR +mDNS -DNSOverTLS DNSSEC=no/unsupported")
    print("resolv.conf mode: stub")
    if servers:
        print(f"Current DNS Server: {servers[0]}")
        print(f"       DNS Servers: {' '.join(servers)}")
    if domains:
        print(f"        DNS Domain: {' '.join(domains)}")


def main():
    tool = sys.argv[1]            # the wrappers in bin/ pass the name they were called by
    args = [a for a in sys.argv[2:] if not a.startswith("--no-")]
    if tool == "resolvectl" and (not args or args[0] == "status"):
        return status() or 0
    if tool == "systemctl" and len(args) == 2 and args[0] in ("restart", "reload-or-restart", "try-restart"):
        unit = args[1].removesuffix(".service")
        if unit != "systemd-resolved":
            print(f"Failed to restart {args[1]}: Unit {unit}.service not found.", file=sys.stderr)
            return 5
        restart()
        return 0
    print(f"mock: {tool} {' '.join(args)} is not supported here", file=sys.stderr)
    return 1


sys.exit(main())
