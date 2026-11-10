#!/bin/bash
# Parse compose.yml and compare it with the intended tree; also compare the file
# line by line (ignoring indentation) so that comments and keys cannot be lost.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s compose.yml ]; then
  echo "❌ compose.yml is missing or empty"
  exit 1
fi

python3 - <<'PY'
import sys, yaml

try:
    got = yaml.safe_load(open("compose.yml"))
except yaml.YAMLError as e:
    mark = getattr(e, "problem_mark", None)
    where = f" (line {mark.line + 1})" if mark else ""
    print(f"❌ compose.yml still does not parse{where}: {getattr(e, 'problem', e)}")
    sys.exit(1)
want = yaml.safe_load(open(".lm-state/fixed.yml"))

try:
    worker = got["services"]["worker"]["image"]
    api = got["services"]["api"]["image"]
except (KeyError, TypeError):
    print("❌ compose.yml parses, but services.api / services.worker are not where they should be")
    sys.exit(1)
if api != want["services"]["api"]["image"]:
    print(f"❌ the api image is now {api}: only the worker image may change")
    sys.exit(1)
if not worker.endswith(":2.7.1"):
    print(f"❌ the worker image is {worker}, expected a :2.7.1 tag")
    sys.exit(1)
if got != want:
    def walk(a, b, path=""):
        if isinstance(a, dict) and isinstance(b, dict):
            for k in sorted(set(a) | set(b), key=str):
                if k not in a: return f"{path}/{k} is missing"
                if k not in b: return f"{path}/{k} is unexpected"
                r = walk(a[k], b[k], f"{path}/{k}")
                if r: return r
            return None
        return None if a == b else f"{path} is {a!r}, expected {b!r}"
    print("❌ the parsed tree differs from the intended one: " + (walk(got, want) or "something else changed"))
    sys.exit(1)

# Same lines in the same order once indentation is ignored: nothing deleted, nothing reordered.
strip = lambda p: [l.strip() for l in open(p).read().splitlines()]
if strip("compose.yml") != strip(".lm-state/fixed.yml"):
    print("❌ the file parses, but lines were added, removed or reordered (comments count too)")
    sys.exit(1)
print("✅ compose.yml parses, worker is on 2.7.1, api untouched, nothing else lost")
PY
