#!/bin/bash
# Runs deploy.sh in scratch copies with a step mock that logs every step, once
# per possible failing step and once with no failure. A failing step must be
# the last line of steps.log (nothing after it, above all no deploy) and the
# exit status non-zero; with no failure all six steps run and it exits 0.
SANDBOX="$1"
SCRIPT="$SANDBOX/deploy.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ deploy.sh is missing (type reset to get it back)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

STEPS="fetch build migrate schema-version verify deploy"

# attempt FAIL: run deploy.sh with FAIL_STEP=FAIL (empty: no failure)
attempt() {
  R="$WORK/run-${1:-ok}"
  mkdir -p "$R/bin"
  cp "$SCRIPT" "$R/deploy.sh"
  cat > "$R/bin/step" <<'MOCK'
#!/bin/bash
echo "$1" >> steps.log
if [ "${FAIL_STEP:-}" = "$1" ]; then echo "$1: FAILED" >&2; exit 1; fi
if [ "$1" = verify ]; then echo "all smoke tests passed"; else echo "$1: ok"; fi
MOCK
  chmod +x "$R/bin/step"
  (cd "$R" && $LIMIT env FAIL_STEP="$1" bash ./deploy.sh </dev/null >"$R/.out" 2>"$R/.err")
  CODE=$?
  GOT="$(cat "$R/steps.log" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
}

# The happy path first: the fix must not break a good deploy.
attempt ""
if [ "$CODE" != 0 ] || [ "$GOT" != "$STEPS" ]; then
  echo "❌ with no failing step, deploy.sh must run '$STEPS' and exit 0; it ran '$GOT' and exited $CODE"
  exit 1
fi

for fail in migrate fetch verify build schema-version; do
  attempt "$fail"
  want="${STEPS%%$fail*}$fail"
  case " $GOT " in *" deploy "*) went_live=yes ;; *) went_live=no ;; esac
  if [ "$GOT" != "$want" ]; then
    if [ "$went_live" = yes ]; then
      echo "❌ with FAIL_STEP=$fail the release still went live (steps run: $GOT)"
    else
      echo "❌ with FAIL_STEP=$fail, deploy.sh should stop right after $fail; steps run: $GOT"
    fi
    exit 1
  fi
  if [ "$CODE" = 0 ]; then
    echo "❌ with FAIL_STEP=$fail, deploy.sh stops but exits 0; a failed deploy needs a non-zero status"
    exit 1
  fi
done

echo "✅ every failing step stops deploy.sh with a non-zero status, and a clean run still deploys"
exit 0
