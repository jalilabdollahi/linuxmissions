#!/bin/bash
# Runs guard.sh over a matrix of DEPLOY_ENV/RELEASE values (unset, empty, with
# spaces, a lone *, near-misses) inside a directory that contains files an
# unquoted glob would match, and checks every exit code and that bash printed
# no errors.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f guard.sh ]; then
  echo "❌ guard.sh is missing (type reset)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
touch "$WORK/prod-eu-9.lock" "$WORK/release-rc-notes.txt" "$WORK/v1.2.3-rc1.tar.gz" "$WORK/1.2.3"
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

# DEPLOY_ENV | RELEASE | expected exit   ("<unset>" = variable not set at all)
CASES=(
  "staging|1.2.3|0"
  "staging|v1.2.3|0"
  "staging|1.2.3-rc1|0"
  "staging|v2.10.0-rc12|0"
  "prod-eu-1|1.2.3|0"
  "prod-us-12|v3.0.1|0"
  "prod-apac-3|10.20.30|0"
  "prod-eu-1|1.2.3-rc1|1"
  "prod-us-12|v1.2.3-rc1|1"
  "<unset>|1.2.3|1"
  "|1.2.3|1"
  "staging|<unset>|1"
  "staging||1"
  "<unset>|<unset>|1"
  "prod eu 1|1.2.3|1"
  "production|1.2.3|1"
  "prod-eu|1.2.3|1"
  "prod-EU-1|1.2.3|1"
  "Staging|1.2.3|1"
  "staging|1.2|1"
  "staging|1.2.3 beta|1"
  "staging|1.2.3.4|1"
  "staging|*|1"
  "prod-eu-1|*|1"
  "staging|1.2.3-rc|1"
  "staging|x1.2.3|1"
  "*|1.2.3|1"
)

show() { [ "$1" = "<unset>" ] && echo "unset" || echo "'$1'"; }

wrong=0; first=""
for c in "${CASES[@]}"; do
  IFS='|' read -r e r want <<< "$c"
  args=(PATH=/usr/bin:/bin HOME="$WORK")
  [ "$e" != "<unset>" ] && args+=("DEPLOY_ENV=$e")
  [ "$r" != "<unset>" ] && args+=("RELEASE=$r")
  (cd "$WORK" && $LIMIT env -i "${args[@]}" bash "$SANDBOX/guard.sh" </dev/null >"$WORK/out" 2>"$WORK/err")
  code=$?
  label="DEPLOY_ENV=$(show "$e") RELEASE=$(show "$r")"
  shellerr="$(grep -E 'line [0-9]+: ' "$WORK/err" | head -1 | sed 's/^.*line [0-9]*: //')"
  problem=""
  if [ -n "$shellerr" ]; then
    problem="$label: bash printed an error ($shellerr)"
  elif [ "$code" -ne "$want" ]; then
    if [ "$want" -eq 0 ]; then
      problem="$label: exit $code, but this deploy is allowed (expected 0)"
    else
      problem="$label: exit $code, but this deploy must be stopped (expected 1)"
    fi
  fi
  if [ -n "$problem" ]; then
    wrong=$(( wrong + 1 ))
    [ -z "$first" ] && first="$problem"
  fi
done

if [ "$wrong" -gt 0 ]; then
  echo "❌ $wrong of ${#CASES[@]} test cases wrong. First: $first"
  exit 1
fi
echo "✅ guard.sh gives the right answer for all ${#CASES[@]} cases, without a single shell error"
exit 0
