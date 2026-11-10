#!/bin/bash
# Rewrite the checks with [[ ]]: no word splitting, no globbing of the
# variables, real patterns on the right of ==, unquoted regexes for =~.
cat > guard.sh <<'EOF'
#!/bin/bash
# guard.sh - pre-deploy gate. The pipeline runs:   ./guard.sh && ./deploy.sh
# Reads DEPLOY_ENV and RELEASE from the environment.
# Exit 0 = the deploy may go ahead, exit 1 = stop. Rules: RULES.txt

stop() { echo "guard: $*" >&2; exit 1; }

[[ -n $DEPLOY_ENV ]] || stop "DEPLOY_ENV is required"
[[ -n $RELEASE ]] || stop "RELEASE is required"

if [[ $DEPLOY_ENV != staging && ! $DEPLOY_ENV =~ ^prod-[a-z]+-[0-9]+$ ]]; then
  stop "unknown environment: $DEPLOY_ENV"
fi

if [[ ! $RELEASE =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?$ ]]; then
  stop "malformed release: $RELEASE"
fi

if [[ $DEPLOY_ENV != staging && $RELEASE == *-rc* ]]; then
  stop "release candidates are not allowed in $DEPLOY_ENV"
fi

echo "guard: ok to deploy $RELEASE to $DEPLOY_ENV"
EOF
DEPLOY_ENV="prod eu 1" RELEASE=1.2.3 ./guard.sh; echo "exit $?"
DEPLOY_ENV=prod-eu-1 RELEASE=v1.2.3 ./guard.sh; echo "exit $?"
