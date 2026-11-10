#!/bin/bash
# $1 = sandbox path
# Runs a copy of rotate.sh in a scratch dir: 7 runs with a new site/VERSION
# marker each time (generation N must hold the marker from N runs ago, at most
# 5 generations), then .3 is deleted and one more run must shift the gap up.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -f rotate.sh ]; then
  echo "❌ rotate.sh does not exist"
  exit 1
fi
if [ ! -x rotate.sh ]; then
  echo "❌ rotate.sh is not executable (cron runs it as ./rotate.sh)"
  exit 1
fi
[ -d site ] || { echo "❌ site/ is gone; type 'reset'"; exit 1; }

T=$(mktemp -d "${TMPDIR:-/tmp}/lm-rotate.XXXXXX")
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
cp -p rotate.sh "$T/"
cp -R site "$T/site"
mkdir "$T/backups"
TO=""; command -v timeout >/dev/null 2>&1 && TO="timeout 15"

run() {  # run R: set the marker, run the script, check exit status
  echo "run-$1" > "$T/site/VERSION"
  if ! ( cd "$T" && SANDBOX="$T" $TO ./rotate.sh ) >/dev/null 2>&1; then
    echo "❌ rotate.sh failed (non-zero exit) on test run $1$2"
    exit 1
  fi
}
gen() {  # gen N: the marker inside backups/site.tar.gz.N, or "none"
  if [ -e "$T/backups/site.tar.gz.$1" ]; then
    tar -xzOf "$T/backups/site.tar.gz.$1" site/VERSION 2>/dev/null || echo broken
  else
    echo none
  fi
}
only_generations() {
  local extra
  extra=$(ls -A "$T/backups" | grep -vx 'site\.tar\.gz\.[1-5]' | head -1)
  if [ -n "$extra" ]; then
    echo "❌ after test run $1, backups/ contains '$extra'; only site.tar.gz.1 ... .5 may be there"
    exit 1
  fi
}

for r in 1 2 3 4 5 6 7; do
  run "$r" " (starting with an empty backups/)"
  only_generations "$r"
  for n in 1 2 3 4 5; do
    if [ $n -le $r ]; then want="run-$((r - n + 1))"; else want=none; fi
    got=$(gen $n)
    if [ "$got" != "$want" ]; then
      if [ "$want" = none ]; then
        echo "❌ after $r test run(s), site.tar.gz.$n exists, but only $r generation(s) should"
      elif [ "$got" = none ]; then
        echo "❌ after $r test run(s), site.tar.gz.$n is missing; it should hold the site from run $((r - n + 1))"
      elif [ "$got" = broken ]; then
        echo "❌ after $r test run(s), site.tar.gz.$n is not a gzip tar of site/"
      else
        echo "❌ after $r test run(s), site.tar.gz.$n holds the site from ${got/run-/run }, expected run $((r - n + 1)) (older generations overwrote newer ones?)"
      fi
      exit 1
    fi
  done
done

rm "$T/backups/site.tar.gz.3"
run 8 " (after site.tar.gz.3 had been deleted)"
only_generations 8
for pair in 1:run-8 2:run-7 3:run-6 4:none 5:run-4; do
  n=${pair%%:*}; want=${pair#*:}
  got=$(gen "$n")
  if [ "$got" != "$want" ]; then
    echo "❌ with .3 missing, every other generation must still move up by one: after the run site.tar.gz.$n should hold ${want/run-/run }, it holds ${got/run-/run }"
    exit 1
  fi
done
echo "✅ rotate.sh keeps five generations in the right order, and a missing generation doesn't break it"
exit 0
