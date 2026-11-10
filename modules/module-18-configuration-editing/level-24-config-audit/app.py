#!/usr/bin/env python3
"""Level-local stand-in for the LinuxMissions demo app (config format 4.x).
  app --check-config   validate etc/app/*; reports only the FIRST problem (exit 1) or "OK" (exit 0)
  app start|stop|status   run the app in the background; start refuses a config that fails the check
The app answers GET / with "linuxapp <APP_VERSION>" on server.port."""
import ipaddress, json, os, re, signal, socket, subprocess, sys, time

ROOT = os.environ.get("LM_ROOT") or os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
CONF = os.path.join(ROOT, "etc/app")
PIDFILE = os.path.join(ROOT, "run/app.pid")


class ConfigError(Exception):
    pass


def rel(p):
    return os.path.relpath(p, ROOT)


def load_ini():
    path = os.path.join(CONF, "app.ini")
    data, section, lines = {}, None, {}
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        line = raw.strip()
        if not line or line[0] in "#;":
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            data.setdefault(section, {})
            continue
        if "=" not in line:
            raise ConfigError(f"{rel(path)}:{n}: expected 'key = value', got '{line}'")
        if section is None:
            raise ConfigError(f"{rel(path)}:{n}: setting outside of a [section]")
        k, v = (x.strip() for x in line.split("=", 1))
        data[section][k] = v
        lines[(section, k)] = n
    for sec in ("server", "database", "logging"):
        if sec not in data:
            raise ConfigError(f"{rel(path)}: missing section [{sec}]")

    def integer(sec, key, lo, hi, required=False):
        if key not in data[sec]:
            if required:
                raise ConfigError(f"{rel(path)}: [{sec}] {key} is required")
            return
        v = data[sec][key]
        if not re.fullmatch(r"\d+", v) or not lo <= int(v) <= hi:
            raise ConfigError(f"{rel(path)}:{lines[(sec, key)]}: [{sec}] {key} must be an integer between {lo} and {hi}, got '{v}'")

    integer("server", "port", 1, 65535)
    integer("server", "workers", 1, 64)
    integer("database", "pool_size", 1, 500)
    if "level" in data["logging"] and data["logging"]["level"] not in ("debug", "info", "warning", "error"):
        raise ConfigError(f"{rel(path)}:{lines[('logging', 'level')]}: [logging] level must be debug, info, warning or error")
    if "url" not in data["database"]:
        raise ConfigError(f"{rel(path)}: [database] url is required")
    if not re.fullmatch(r"postgres://[^:@/]+(:[^@/]*)?@[A-Za-z0-9.-]+(:\d+)?/\w+", data["database"]["url"]):
        raise ConfigError(f"{rel(path)}:{lines[('database', 'url')]}: [database] url is not a postgres:// URL")
    return data


def load_env():
    path = os.path.join(CONF, "app.env")
    env = {}
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        m = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)=(.*)", raw)
        if not m:
            raise ConfigError(f"{rel(path)}:{n}: not a KEY=VALUE line (no spaces around '=' in an env file): '{raw}'")
        env[m.group(1)] = (m.group(2), n)
    if env.get("APP_ENV", ("", 0))[0].strip("\"'") not in ("production", "staging", "development"):
        v = env.get("APP_ENV", ("(unset)", 0))
        raise ConfigError(f"{rel(path)}:{v[1]}: APP_ENV must be production, staging or development, got '{v[0]}'")
    v = env.get("APP_VERSION", ("(unset)", 0))
    if not re.fullmatch(r"\d+\.\d+\.\d+", v[0].strip("\"'")):
        raise ConfigError(f"{rel(path)}:{v[1]}: APP_VERSION must look like 1.2.3, got '{v[0]}'")
    if not env.get("SECRET_KEY", ("", 0))[0]:
        raise ConfigError(f"{rel(path)}: SECRET_KEY is required")
    return {k: v[0].strip("\"'") for k, v in env.items()}


def load_features():
    path = os.path.join(CONF, "features.json")

    def no_dups(pairs):
        seen = {}
        for k, v in pairs:
            if k in seen:
                raise ConfigError(f"{rel(path)}: duplicate key \"{k}\" (the parser would silently keep the last one)")
            seen[k] = v
        return seen

    try:
        data = json.loads(open(path).read(), object_pairs_hook=no_dups)
    except json.JSONDecodeError as e:
        raise ConfigError(f"{rel(path)}:{e.lineno}: invalid JSON: {e.msg}")
    feats = data.get("features") if isinstance(data, dict) else None
    if not isinstance(feats, dict):
        raise ConfigError(f"{rel(path)}: expected an object under \"features\"")
    for k, v in feats.items():
        if not isinstance(v, bool):
            raise ConfigError(f"{rel(path)}: feature \"{k}\" must be true or false")
    return feats


def load_services():
    import yaml
    path = os.path.join(CONF, "services.yml")
    try:
        data = yaml.safe_load(open(path))
    except yaml.YAMLError as e:
        mark = getattr(e, "problem_mark", None)
        raise ConfigError(f"{rel(path)}:{mark.line + 1 if mark else '?'}: invalid YAML: {getattr(e, 'problem', e)}")
    svcs = data.get("services") if isinstance(data, dict) else None
    if not isinstance(svcs, dict) or not svcs:
        raise ConfigError(f"{rel(path)}: expected a mapping named 'services'")
    for name, s in svcs.items():
        if not isinstance(s, dict) or not isinstance(s.get("host"), str):
            raise ConfigError(f"{rel(path)}: services.{name}.host must be a string")
        if not isinstance(s.get("port"), int) or isinstance(s.get("port"), bool):
            raise ConfigError(f"{rel(path)}: services.{name}.port must be an integer, got {s.get('port')!r} ({type(s.get('port')).__name__})")
    return svcs


def load_hosts():
    path = os.path.join(CONF, "hosts")
    names = {}
    for n, raw in enumerate(open(path).read().splitlines(), 1):
        line = raw.split("#", 1)[0].split()
        if not line:
            continue
        try:
            ipaddress.ip_address(line[0])
        except ValueError:
            raise ConfigError(f"{rel(path)}:{n}: invalid IP address '{line[0]}'")
        if len(line) < 2:
            raise ConfigError(f"{rel(path)}:{n}: no host name after the address")
        for name in line[1:]:
            names.setdefault(name, line[0])
    return names


def check():
    ini = load_ini()
    load_env()
    load_features()
    load_services()
    names = load_hosts()
    host = re.search(r"@([A-Za-z0-9.-]+)", ini["database"]["url"]).group(1)
    if host != "localhost" and host not in names:
        raise ConfigError(f"cannot resolve database host '{host}': it is not in {rel(os.path.join(CONF, 'hosts'))}")
    return ini


def serve():
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    ini, env = check(), load_env()
    body = f"linuxapp {env['APP_VERSION']}\n".encode()

    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            out = b"ok\n" if self.path == "/health" else body
            self.send_response(200)
            self.send_header("Content-Length", str(len(out)))
            self.end_headers()
            self.wfile.write(out)

        def log_message(self, *a):
            pass

    ThreadingHTTPServer.allow_reuse_address = True
    ThreadingHTTPServer((ini["server"].get("host", "127.0.0.1"), int(ini["server"]["port"])), H).serve_forever()


def running():
    try:
        pid = int(open(PIDFILE).read())
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError):
        return None


def main():
    args = sys.argv[1:]
    if args == ["--check-config"]:
        try:
            check()
        except ConfigError as e:
            print(f"app: config error: {e}")
            return 1
        print("app: configuration OK (5 files)")
        return 0
    if args == ["--serve"]:
        serve()
        return 0
    if args == ["start"]:
        if running():
            print(f"app: already running (pid {running()})")
            return 0
        try:
            ini = check()
        except ConfigError as e:
            print(f"app: refusing to start: {e}")
            return 1
        os.makedirs(os.path.dirname(PIDFILE), exist_ok=True)
        p = subprocess.Popen([sys.executable, os.path.realpath(__file__), "--serve"], stdin=subprocess.DEVNULL,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        open(PIDFILE, "w").write(str(p.pid))
        port = int(ini["server"].get("port", 8080))
        for _ in range(40):
            try:
                socket.create_connection(("127.0.0.1", port), timeout=0.2).close()
                print(f"app: started (pid {p.pid}), listening on {ini['server'].get('host', '127.0.0.1')}:{port}")
                return 0
            except OSError:
                time.sleep(0.1)
        print("app: failed to start (port in use?)")
        return 1
    if args == ["stop"]:
        pid = running()
        if not pid:
            print("app: not running")
            return 0
        os.kill(pid, signal.SIGTERM)
        print("app: stopped")
        return 0
    if args == ["status"]:
        pid = running()
        print(f"app: running (pid {pid})" if pid else "app: not running")
        return 0 if pid else 3
    print("usage: app --check-config | start | stop | status", file=sys.stderr)
    return 2


sys.exit(main())
