#!/bin/bash
# Release Notes: an exported `git log --oneline --decorate`, newest first. Commits after v2.4.0 and
# before v2.3.0 are decoys; inside the range there are chores, merges, a breaking change and
# one revert pair. The exact expected file is written to .lm/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm
python3 - <<'PY' || exit 1
import random
r = random.Random()
prs = iter(r.sample(range(300, 999), 200))
def h(): return "".join(r.choice("0123456789abcdef") for _ in range(7))
scopes = ["api", "cli", "db", "auth", "ui", "queue", "cache", "export", "billing", "search"]
feat_t = ["Add bulk import endpoint", "Support dark theme in the console", "Add --dry-run to the migrate command", "Expose queue depth metric",
          "Allow per-tenant rate limits", "Add CSV export for invoices", "Support SSO group mapping", "Add search by tag", "Stream logs over websocket",
          "Add health probe for workers", "Add audit trail view", "Cache compiled templates"]
fix_t = ["Retry on database timeout", "Stop duplicating webhook events", "Handle empty tenant name", "Fix pagination off-by-one", "Close idle connections",
         "Escape quotes in CSV output", "Keep sort order after refresh", "Fix crash on missing locale", "Correct VAT rounding", "Avoid double charge on retry"]
other_t = ["chore(deps): bump openssl to 3.0.14", "chore: update CI image", "docs: explain rate limits", "docs(api): fix typos", "ci: cache dependencies",
           "test(db): add migration tests", "refactor(core): extract config loader", "style: apply formatter", "build: pin python to 3.12", "perf(search): lazy load index"]
nouns = ["bulk import endpoint", "dark theme", "queue depth metric", "tenant rate limits", "CSV export", "SSO group mapping", "tag search",
         "websocket log stream", "worker health probe", "audit trail view", "template cache", "invoice archive", "retention policy", "API tokens", "webhook replay"]
feat_t += [f"{v} {n}" for v in ("Add", "Support", "Expose") for n in nouns]
bugs = ["database timeouts", "duplicate webhooks", "empty tenant names", "pagination", "idle connections", "CSV quoting", "sort order", "missing locale",
        "VAT rounding", "double charges", "login redirect", "export encoding", "stale cache entries", "queue stalls", "timezone offsets"]
fix_t += [f"{v} {n}" for v in ("Fix", "Handle", "Correct") for n in bugs]
feat_t = sorted(set(feat_t)); fix_t = sorted(set(fix_t))
r.shuffle(feat_t); r.shuffle(fix_t); r.shuffle(other_t)
def commit(kind, bang=False, pool=None):
    t = pool.pop()
    return f"{kind}({r.choice(scopes)}){'!' if bang else ''}: {t} (#{next(prs)})"
def mergecommit():
    return f"Merge pull request #{next(prs)} from team/{r.choice(['topic','fix','work'])}-{r.randint(1,99)}"
before_new, after_old = [], []
for _ in range(r.randint(3, 5)): after_old.append(commit(r.choice(["feat", "fix"]), pool=feat_t if r.random() < .5 else fix_t))
after_old = [a if a.split("(")[0] in ("feat", "fix") else a for a in after_old]
# range commits, oldest first
rng = []
nfeat, nfix = r.randint(2, 4), r.randint(2, 4)
feats = [commit("feat", pool=feat_t) for _ in range(nfeat)]
fixes = [commit("fix", pool=fix_t) for _ in range(nfix)]
breaking = [commit(r.choice(["feat", "fix"]), bang=True, pool=feat_t if r.random() < .5 else fix_t)]
reverted_fix = commit("fix", pool=fix_t)
reverted_feat = commit("feat", pool=feat_t)
others = [other_t.pop() for _ in range(r.randint(4, 6))] + [mergecommit() for _ in range(r.randint(2, 3))]
body = feats + fixes + breaking + others
r.shuffle(body)
# reverted change somewhere, its revert later
reverted = r.choice([reverted_fix, reverted_feat])
other_unreverted = reverted_feat if reverted is reverted_fix else reverted_fix
body.append(other_unreverted)
i = r.randint(0, len(body) - 1); body.insert(i, reverted)
j = r.randint(i + 1, len(body)); body.insert(j, f'Revert "{reverted.rsplit(" (#", 1)[0]}" (#{next(prs)})')
old = [commit(r.choice(["feat", "fix"]), pool=feat_t if r.random() < .5 else fix_t) for _ in range(r.randint(3, 5))]
lines = []
for c in after_old[::-1][:0]: pass
new_part = after_old
log = []
log += [(c, "") for c in new_part]
log += [("chore: release 2.4.0", "tag: v2.4.0")]
log += [(c, "") for c in reversed(body)]
log += [("chore: release 2.3.0", "tag: v2.3.0")]
log += [(c, "") for c in old]
with open("gitlog.txt", "w") as f:
    for k, (c, deco) in enumerate(log):
        d = ""
        if k == 0: d = " (HEAD -> main, origin/main)"
        if deco: d = f" ({deco}{', origin/release' if deco.endswith('v2.4.0') else ''})"
        f.write(f"{h()}{d} {c}\n")
open("RELEASE_NOTES.template", "w").write(
"""# Release v2.4.0

## Features

- <summary> (#<PR>)

## Fixes

- <summary> (#<PR>)

## Breaking

- <summary> (#<PR>)
""")
import re
def text(c): return re.sub(r"^[a-z]+(\([^)]*\))?!?: ", "", c)
kept = [c for c in body if c not in (reverted,) and not c.startswith(("Revert", "Merge")) and re.match(r"^(feat|fix)(\([^)]*\))?!?: ", c)]
sec = lambda pat: [f"- {text(c)}" for c in kept if re.match(pat, c)]
out = ["# Release v2.4.0", "", "## Features", ""] + sec(r"^feat(\([^)]*\))?: ") + ["", "## Fixes", ""] + sec(r"^fix(\([^)]*\))?: ") + \
      ["", "## Breaking", ""] + sec(r"^[a-z]+(\([^)]*\))?!: ")
open(".lm/expected.md", "w").write("\n".join(out) + "\n")
open(".lm/reverted.txt", "w").write(text(reverted) + "\n")
open(".lm/outside.txt", "w").write("\n".join(text(c) for c in new_part + old) + "\n")
PY
