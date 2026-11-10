#!/bin/bash
# Sources a copy of team/aliases.sh in a clean bash (aliases enabled), sets
# LOGDIR only afterwards (twice, to two different logs) and exercises each helper.
SANDBOX="$1"
FILE="$SANDBOX/team/aliases.sh"

if [ ! -f "$FILE" ]; then
  echo "❌ team/aliases.sh is missing (type reset to get it back)"
  exit 1
fi
WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp "$FILE" "$WORK/aliases.sh"
mkdir -p "$WORK/logA" "$WORK/logB" "$WORK/home"
for d in A B; do
  for i in $(seq 1 45); do echo "log$d line $i $RANDOM"; done > "$WORK/log$d/app.log"
done
NEW="$WORK/home/proj $RANDOM/src"

cat > "$WORK/t.sh" <<'EOF'
shopt -s expand_aliases
cd "$W/home"
source "$W/aliases.sh" 2>"$W/src.err"
LOGDIR="$W/logA"
logs >"$W/outA" 2>&1
LOGDIR="$W/logB"
logs >"$W/outB" 2>&1
echo "tmkcd=$(type -t mkcd)"
mkcd "$NEW" 2>/dev/null
echo "pwd=$PWD"
alias rm ll gs .. 2>/dev/null
EOF

LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"
out="$(cd "$WORK" && $LIMIT env -i HOME="$WORK/home" PATH="$PATH" W="$WORK" NEW="$NEW" bash --noprofile --norc "$WORK/t.sh" </dev/null 2>/dev/null)"

if [ -s "$WORK/src.err" ]; then
  echo "❌ sourcing aliases.sh prints an error: $(head -1 "$WORK/src.err" | sed "s#$WORK/##")"
  exit 1
fi

if ! tail -n 20 "$WORK/logA/app.log" | cmp -s - "$WORK/outA" || ! tail -n 20 "$WORK/logB/app.log" | cmp -s - "$WORK/outB"; then
  if grep -q 'logA' "$WORK/outB"; then
    echo "❌ logs keeps showing the first LOGDIR after LOGDIR changed; the path is still fixed when the alias is defined"
  elif grep -q '/app.log' "$WORK/outA"; then
    echo "❌ logs still reads /app.log: \$LOGDIR was expanded (empty) when the alias was defined, not when it runs"
  else
    echo "❌ logs (run after setting LOGDIR) does not print the last 20 lines of \$LOGDIR/app.log"
  fi
  exit 1
fi

tmkcd="$(printf '%s\n' "$out" | sed -n 's/^tmkcd=//p')"
if [ "$tmkcd" != function ]; then
  if [ "$tmkcd" = alias ]; then
    echo "❌ mkcd is still an alias; aliases just paste text and can't use \$1, so make it a function"
  else
    echo "❌ mkcd is not defined as a function after sourcing aliases.sh"
  fi
  exit 1
fi
if [ ! -d "$NEW" ]; then
  echo "❌ mkcd \"a/dir with spaces/src\" did not create that directory (parents included); quote \"\$1\""
  exit 1
fi
if [ "$(printf '%s\n' "$out" | sed -n 's/^pwd=//p')" != "$NEW" ]; then
  echo "❌ mkcd created the directory but did not leave the shell inside it"
  exit 1
fi

for want in "alias rm='rm -i'" "alias ll='ls -lah'" "alias gs='git status -sb'" "alias ..='cd ..'"; do
  if ! printf '%s\n' "$out" | grep -qxF -- "$want"; then
    name="${want#alias }"; name="${name%%=*}"
    if [ "$name" = rm ]; then
      echo "❌ rm is not aliased to exactly 'rm -i' yet"
    else
      echo "❌ the $name alias changed or disappeared; keep it as it was ($want)"
    fi
    exit 1
  fi
done

echo "✅ logs follows LOGDIR at run time, mkcd is a function, and rm asks first"
exit 0
