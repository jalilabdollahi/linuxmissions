#!/bin/bash
# Gatekeeper: guard.sh decides whether a deploy may go ahead. It uses unquoted
# variables inside [ ], a loose glob for versions, a literal compare where a
# pattern was meant, and lets errors from [ count as "not a problem". The
# validator runs it over a matrix of inputs in a directory with glob bait files.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > guard.sh <<'EOF'
#!/bin/bash
# guard.sh - pre-deploy gate. The pipeline runs:   ./guard.sh && ./deploy.sh
# Reads DEPLOY_ENV and RELEASE from the environment.
# Exit 0 = the deploy may go ahead, exit 1 = stop. Rules: RULES.txt

stop() { echo "guard: $*" >&2; exit 1; }

# Both inputs are required.
[ -n $DEPLOY_ENV ] || stop "DEPLOY_ENV is required"
[ -n $RELEASE ] || stop "RELEASE is required"

# Only staging and the production stacks exist.
if [ $DEPLOY_ENV != staging ] && [[ $DEPLOY_ENV != prod-* ]]; then
  stop "unknown environment: $DEPLOY_ENV"
fi

# Release tags look like 1.2.3
if [[ $RELEASE != [0-9]*.[0-9]*.[0-9]* ]]; then
  stop "malformed release: $RELEASE"
fi

# Production never gets release candidates.
if [ $DEPLOY_ENV != staging ] && [ $RELEASE = *-rc* ]; then
  stop "release candidates are not allowed in $DEPLOY_ENV"
fi

echo "guard: ok to deploy $RELEASE to $DEPLOY_ENV"
EOF
chmod +x guard.sh

cat > RULES.txt <<'EOF'
Deploy rules (enforced by guard.sh, exit 0 = go, exit 1 = stop)
---------------------------------------------------------------
1. DEPLOY_ENV and RELEASE must both be set and non-empty.
2. DEPLOY_ENV is exactly "staging", or a production stack named
   prod-<region>-<number>: region in lowercase letters, number in digits
   (prod-eu-1, prod-us-12). Anything else is unknown: stop.
3. RELEASE is a version tag: MAJOR.MINOR.PATCH in digits, optionally with a
   leading "v" and optionally ending in -rc<digits> (1.2.3, v1.2.3, 1.2.3-rc1,
   v2.10.0-rc12). Anything else is malformed: stop.
4. Release candidates (-rc) may go to staging, never to production.
guard.sh must answer every input with exit 0 or exit 1, and never print a
shell error.
EOF

# The repo checkout the pipeline runs in (glob bait for unquoted patterns).
touch prod-eu-9.lock release-rc-notes.txt
printf '#!/bin/bash\necho "deploying $RELEASE to $DEPLOY_ENV"\n' > deploy.sh
chmod +x deploy.sh
