#!/bin/bash
# Semver Basics: a random commit log (one of four bump scenarios, with decoys), a package.json,
# and a tag list with rc.N tags and non-release tags. Expected values go to .lm/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm
python3 - <<'PY' || exit 1
import json, random, re
r = random.Random()
scen = r.choice(["feat!", "footer", "feat", "fix"])
scopes = ["cli", "api", "auth", "config", "output", "parser", "cache", "net"]
feats = ["add --json output", "support config includes", "add retry flag", "new 'status' subcommand", "read tokens from env", "add shell completion"]
fixes = ["handle empty input", "stop leaking file handles", "respect NO_COLOR", "fix off-by-one in pager", "close socket on timeout", "keep order of keys", "retry on EAGAIN"]
chores = ["chore(deps): bump lodash to 4.17.22", "chore: update CI image", "docs: explain the BREAKING CHANGE footer", "docs(readme): refresh install steps",
          "test(parser): cover empty files", "ci: cache the build directory", "refactor(core): split main.c", "style: run formatter", "chore: release tooling cleanup"]
def h():
    return "".join(r.choice("0123456789abcdef") for _ in range(7))
commits = []
for _ in range(r.randint(3, 6)):
    commits.append((f"fix({r.choice(scopes)}): {r.choice(fixes)}", ""))
for t in r.sample(chores, 5):
    commits.append((t, ""))
if scen in ("feat", "feat!", "footer"):
    for _ in range(r.randint(1, 3)):
        commits.append((f"feat({r.choice(scopes)}): {r.choice(feats)}", ""))
if scen == "feat!":
    commits.append((f"feat({r.choice(scopes)})!: drop support for the v1 protocol", "The v1 wire format is gone."))
if scen == "footer":
    commits.append((f"fix({r.choice(scopes)}): change default exit code on failure",
                    "Scripts that test for 1 must now test for 2.\n\nBREAKING CHANGE: exit code is 2 on failure"))
if scen in ("feat", "fix"):
    commits.append(("fix(core): keep old 'breaking' flag working", "Refs: BREAKING CHANGE policy, see docs"))
# unique subjects
seen, uniq = set(), []
for c in commits:
    if c[0] not in seen: seen.add(c[0]); uniq.append(c)
commits = uniq
r.shuffle(commits)
with open("commits.txt", "w") as f:
    for subj, body in commits:
        f.write(f"{h()} {subj}\n")
        if body: f.write(body + "\n")
        f.write("\n")
ver = {"feat!": "3.0.0", "footer": "3.0.0", "feat": "2.4.0", "fix": "2.3.5"}[scen]
open("VERSION", "w").write("2.3.4\n")
pj = {"name": "lmctl", "version": "2.3.4", "description": "LinuxMissions control CLI", "bin": {"lmctl": "bin/lmctl.js"},
      "scripts": {"test": "node test/run.js"}, "license": "MIT"}
json.dump(pj, open("package.json", "w"), indent=2); open("package.json", "a").write("\n")
json.dump({k: v for k, v in pj.items() if k != "version"}, open(".lm/package.rest.json", "w"), sort_keys=True)
open(".lm/version.expected", "w").write(ver + "\n")
# tags
tags = []
for minor in range(0, 3):
    for patch in range(0, r.randint(1, 4)):
        tags.append(f"v1.{minor}.{patch}")
tags.append("v1.0.0-rc.1")
for pre in ("alpha.1", "beta.1", "beta.2"):
    tags.append(f"v2.0.0-{pre}")
for k in range(1, r.randint(2, 4)): tags.append(f"v2.0.{k}")
tags += ["v2.0.0"]
tags += [f"v2.1.{k}" for k in range(0, r.randint(1, 3))] + [f"v2.2.{k}" for k in range(0, r.randint(1, 4))]
nrc = r.randint(9, 12)
tags += [f"v2.3.0-rc.{k}" for k in range(1, nrc + 1)]
tags += [f"v2.3.{k}" for k in range(0, 5)]
tags += ["latest", f"nightly-2026{r.randint(1,9):02d}{r.randint(10,28)}", f"build-{r.randint(1000, 9999)}", "v2.3", "release-candidate"]
tags = sorted(set(tags)); r.shuffle(tags)
open("all-tags.txt", "w").write("\n".join(tags) + "\n")
def key(t):
    m = re.match(r"^v(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$", t)
    core = tuple(int(x) for x in m.groups()[:3])
    pre = m.group(4)
    if pre is None: return (core, 1, ())
    return (core, 0, tuple((0, int(p), "") if p.isdigit() else (1, 0, p) for p in pre.split(".")))
rel = [t for t in tags if re.match(r"^v\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$", t)]
top = sorted(rel, key=key)[-10:]
open(".lm/tags.expected", "w").write("\n".join(top) + "\n")
PY
