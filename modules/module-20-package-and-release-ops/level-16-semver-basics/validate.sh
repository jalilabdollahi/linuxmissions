#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
want=$(cat .lm/version.expected)
if [ ! -f VERSION ]; then
  echo "❌ VERSION is missing"
  exit 1
fi
got=$(tr -d '[:space:]' < VERSION)
if [ "$got" = "2.3.4" ]; then
  echo "❌ VERSION still says 2.3.4: decide the next version from commits.txt"
  exit 1
fi
if [ "$got" != "$want" ]; then
  if [ "${got#v}" != "$got" ]; then
    echo "❌ VERSION should hold the bare number, without the leading v"
  else
    echo "❌ VERSION says $got, which is not what the commits since v2.3.4 call for (check breaking changes, features and fixes separately)"
  fi
  exit 1
fi
if ! jq -e . package.json >/dev/null 2>&1; then
  echo "❌ package.json is not valid JSON any more"
  exit 1
fi
pv=$(jq -r '.version' package.json)
if [ "$pv" != "$want" ]; then
  echo "❌ package.json says version $pv, it must match VERSION"
  exit 1
fi
if [ "$(jq -S -c 'del(.version)' package.json)" != "$(jq -S -c . .lm/package.rest.json)" ]; then
  echo "❌ package.json changed in more places than the version field"
  exit 1
fi
if [ ! -s tags.txt ]; then
  echo "❌ tags.txt does not exist yet (or is empty)"
  exit 1
fi
n=$(wc -l < tags.txt)
if [ "$n" -ne 10 ]; then
  echo "❌ tags.txt has $n lines, expected the ten highest release tags"
  exit 1
fi
if grep -vqE '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' tags.txt; then
  echo "❌ tags.txt contains something that is not a release tag (vMAJOR.MINOR.PATCH[-prerelease])"
  exit 1
fi
if ! diff -q <(LC_ALL=C sort tags.txt) <(LC_ALL=C sort .lm/tags.expected) >/dev/null; then
  echo "❌ tags.txt does not hold the ten highest release tags by semver precedence (a prerelease is lower than its release; numeric parts compare as numbers)"
  exit 1
fi
if ! cmp -s tags.txt .lm/tags.expected; then
  echo "❌ tags.txt has the right ten tags but not in semver order (lowest first)"
  exit 1
fi
echo "✅ next version is $want in VERSION and package.json, and the ten highest tags are in semver order"
