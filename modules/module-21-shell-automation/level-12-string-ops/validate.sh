#!/bin/bash
# Runs parse_artifact.sh with an empty environment and PATH=/nonexistent, so
# no external program can run, on valid names (hyphens and digits in the app
# name, directories with dots) and invalid ones, and compares stdout, stderr
# and the exit status. Programs called by absolute path are refused too.
SANDBOX="$1"
SCRIPT="$SANDBOX/parse_artifact.sh"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ parse_artifact.sh is missing (type reset to get it back)"
  exit 1
fi
if sed 1d "$SCRIPT" | grep -v '^[[:space:]]*#' | grep -Eq '(^|[^A-Za-z0-9_.])/(usr/)?(local/)?s?bin/[a-z]'; then
  echo "❌ parse_artifact.sh calls a program by its full path; the runner only has bash itself"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp "$SCRIPT" "$WORK/parse_artifact.sh"
cd "$WORK" || exit 1
BASH_BIN=$(command -v bash)
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

run() {
  $LIMIT env -i PATH=/nonexistent "$BASH_BIN" ./parse_artifact.sh "$1" </dev/null >out 2>err
  CODE=$?
}

# ARGUMENT | expected line
GOOD=(
  "dist/log-shipper-2.4.1-linux-amd64.tar.gz|name=log-shipper version=2.4.1 os=linux arch=amd64 ext=tar.gz"
  "k8s-node-agent-0.19.0-linux-arm64.tar.xz|name=k8s-node-agent version=0.19.0 os=linux arch=arm64 ext=tar.xz"
  "x509-tool-10.0.12-freebsd-386.zip|name=x509-tool version=10.0.12 os=freebsd arch=386 ext=zip"
  "/srv/builds.v2/api-1.0.0-windows-amd64.zip|name=api version=1.0.0 os=windows arch=amd64 ext=zip"
  "out/data-sync-3-2.0.0-linux-armv7.tar.gz|name=data-sync-3 version=2.0.0 os=linux arch=armv7 ext=tar.gz"
  "a-1-2-3.4.5-darwin-arm64.tar.gz|name=a-1-2 version=3.4.5 os=darwin arch=arm64 ext=tar.gz"
)
BAD=(
  "dist/checksums.txt"
  "tool-1.2-linux-amd64.tar.gz"
  "tool-linux-amd64.zip"
  "-1.2.3-linux-amd64.zip"
  "tool-1.2.3-linux-amd64.tar.bz2"
  "Tool-1.2.3-linux-amd64.zip"
  "tool-1.2.3-linux-amd64"
  "my tool-1.2.3-linux-amd64.zip"
  "tool-1.2.3-linux-amd64.tar.gz.sig"
  ""
)

for c in "${GOOD[@]}"; do
  arg=${c%%|*}
  want=${c#*|}
  run "$arg"
  if grep -q 'command not found' err; then
    echo "❌ parse_artifact.sh '$arg' tried to run an external program: $(grep -m1 'command not found' err)"
    exit 1
  fi
  if [ "$CODE" != 0 ] || [ "$(cat out)" != "$want" ]; then
    echo "❌ parse_artifact.sh '$arg' printed '$(head -n 1 out)' (exit $CODE), expected '$want'"
    exit 1
  fi
done

for arg in "${BAD[@]}"; do
  run "$arg"
  if grep -q 'command not found' err; then
    echo "❌ parse_artifact.sh '$arg' tried to run an external program: $(grep -m1 'command not found' err)"
    exit 1
  fi
  if [ "$CODE" != 1 ] || [ -s out ] || [ "$(cat err)" != "parse_artifact: not an artifact name: $arg" ]; then
    echo "❌ parse_artifact.sh '$arg' is not an artifact name: expected exit 1, nothing on stdout and the error line on stderr (got exit $CODE, stdout '$(head -n 1 out)')"
    exit 1
  fi
done

echo "✅ parse_artifact.sh splits every artifact name with bash alone and rejects the rest"
exit 0
