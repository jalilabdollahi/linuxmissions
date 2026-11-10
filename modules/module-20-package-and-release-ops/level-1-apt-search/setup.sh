#!/bin/bash
# Find the Right Package: a 400-package index (no .debs needed, only search and
# show are used). The real tool's name is picked at random; around it sit its
# library, headers, docs, a schema generator and a formatter.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
MOCKS="$(cd "$(dirname "$0")/../../../mocks" && pwd)"
mkdir -p "$SANDBOX/.lm"
python3 - "$SANDBOX" "$MOCKS" <<'PY' || exit 1
import json, random, sys
sandbox, mocks = sys.argv[1:3]
sys.path.insert(0, mocks + "/packages")
import pkgsim

rnd = random.Random()
tool = rnd.choice(["jsonvet", "schemacop", "vschema", "jschk", "docucheck"])
gen = tool + "gen" if tool != "jschk" else "schemagen"

def pkg(name, synopsis, long="", section="utils", ver=None, **kw):
    d = synopsis + ("\n" + long if long else "")
    return dict(name=name, version=ver or f"{rnd.randint(0,4)}.{rnd.randint(0,19)}.{rnd.randint(0,9)}-1",
                description=d, section=section, **kw)

pk = [
    pkg(tool, "command-line JSON Schema validator",
        "Checks JSON documents against a schema and exits non-zero on the first\ndocument that does not conform. Reads files or standard input."),
    pkg("python3-" + tool, "JSON schema validation library for Python",
        "Validate JSON schemas and JSON documents from Python code. Supports the\ncurrent drafts of the JSON Schema specification.", section="python"),
    pkg("lib" + tool + "-dev", "development files for the JSON schema validation library",
        "Headers and static library for building programs that validate JSON\nagainst a schema.", section="libdevel"),
    pkg(tool + "-doc", "user manual and examples for the " + tool + " schema validator",
        "Tutorials, the schema cookbook and worked JSON examples.", section="doc"),
    pkg(gen, "command-line JSON Schema generator",
        "Infers a schema from sample JSON documents and prints it.\nUseful as a starting point for a hand-written schema."),
    pkg("jsonfmt", "command-line JSON formatter and pretty printer",
        "Re-indents JSON read from files or standard input."),
    pkg("xmlschema-tools", "tools for working with XML schema files",
        "Validate XML documents against XSD schema files."),
    pkg("sql-schema-diff", "compare two database schemas",
        "Prints the ALTER statements that turn one SQL schema into another."),
    pkg("libjson-glib-1.0-0", "GLib JSON manipulation library", section="libs"),
    pkg("jq-lite", "lightweight command-line JSON processor", "Filter and transform JSON with a small expression language."),
]
stems = ["ack", "bar", "cal", "dune", "elk", "fox", "gale", "hawk", "ink", "jade", "kite", "lark", "moth",
         "nest", "orca", "pine", "quill", "reed", "sage", "tern", "umber", "vole", "wren", "yarrow", "zinc"]
ends = ["", "d", "ctl", "tool", "util", "sync", "view", "mon", "cfg", "pack", "scan", "log", "net"]
what = ["monitor", "archive", "converter", "scheduler", "indexer", "profiler", "mirror", "renamer",
        "uploader", "decoder", "linter", "planner", "tracker", "watcher"]
what2 = ["log files", "disk images", "calendar data", "CSV exports", "network sockets", "fonts",
         "audio streams", "config files", "mail queues", "git repositories", "build caches"]
used = {p["name"] for p in pk}
while len(pk) < 400:
    name = rnd.choice(stems) + rnd.choice(ends)
    if rnd.random() < 0.25:
        name = rnd.choice(["lib", "python3-", "node-"]) + name + rnd.choice(["", "1", "-dev", "-doc"])
    if name in used:
        continue
    used.add(name)
    kind = rnd.choice(what)
    desc = f"{rnd.choice(['fast', 'small', 'simple', 'scriptable', 'portable'])} {kind} for {rnd.choice(what2)}"
    if rnd.random() < 0.03:
        desc = f"{kind} for JSON {rnd.choice(['logs', 'streams', 'APIs'])}"
    pk.append(pkg(name, desc))

fx = {"repos": [{"name": "mirror", "suite": "noble", "origin": "Mirror", "debs": False, "packages": pk}]}
try:
    pkgsim.build(sandbox, fx)
except pkgsim.FixtureError as e:
    print(e); sys.exit(1)
open(sandbox + "/.lm/tool", "w").write(tool + "\n")
PY
