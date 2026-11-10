#!/bin/bash
# Wargame 17: deployctl 2.4.1 is installed but CI runs 1.x. Three real shadows
# (a BASH_ENV function, a stale ~/.local/bin symlink, a /usr/local/bin wrapper)
# and two decoys that only matter in interactive/login shells.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf home opt usr deploy-sim shadows.txt .lm
OLD="1.$((6 + RANDOM % 4)).$((RANDOM % 9))"
mkdir -p home/ci/.local/bin usr/local/bin opt/deployctl-$OLD/bin opt/deployctl-2.4.1/bin .lm

printf '#!/bin/sh\necho "deployctl %s"\n' "$OLD" > opt/deployctl-$OLD/bin/deployctl
printf '#!/bin/sh\necho "deployctl 2.4.1"\n' > opt/deployctl-2.4.1/bin/deployctl
chmod 755 opt/deployctl-*/bin/deployctl

# shadow 1: BASH_ENV file defines an exported function
cat > home/ci/.ci_env <<ENVF
# CI shell setup (read by every non-interactive bash through BASH_ENV)
export DEPLOY_ENV=prod
export CI=1
deployctl() { $SANDBOX/opt/deployctl-$OLD/bin/deployctl "\$@"; }
export -f deployctl
ENVF
# shadow 2: stale link from the old installer
ln -s ../../../opt/deployctl-$OLD/bin/deployctl home/ci/.local/bin/deployctl
# shadow 3: compatibility wrapper somebody dropped into /usr/local/bin
printf '#!/bin/sh\n# compat wrapper, see ticket OPS-1187\nexec %s/opt/deployctl-%s/bin/deployctl "$@"\n' "$SANDBOX" "$OLD" > usr/local/bin/deployctl
chmod 755 usr/local/bin/deployctl
# decoys: only interactive or login shells read these
cat > home/ci/.bashrc <<RC
alias deployctl='$SANDBOX/opt/deployctl-$OLD/bin/deployctl'
RC
cat > home/ci/.profile <<PR
export PATH="$SANDBOX/opt/deployctl-$OLD/bin:\$PATH"
PR

cat > deploy-sim <<'SIM'
#!/bin/bash
# Runs the deploy job the way the CI runner does: clean environment, a plain
# non-interactive bash, the runner user's HOME, and the runner's PATH.
SB="$(cd "$(dirname "$0")" && pwd)"
CI_HOME="$SB/home/ci"
CI_PATH="$CI_HOME/.local/bin:$SB/usr/local/bin:$SB/opt/deployctl-2.4.1/bin:/usr/bin:/bin"
if [ "$1" = "--which" ]; then
  job='echo "kind=$(type -t deployctl)"; echo "path=$(type -P deployctl)"'
else
  job='echo "deploy-sim: target=${DEPLOY_ENV:-unset}"; deployctl --version'
fi
exec env -i HOME="$CI_HOME" USER=ci PATH="$CI_PATH" BASH_ENV="$CI_HOME/.ci_env" \
  bash --noprofile --norc -c "$job"
SIM
chmod 755 deploy-sim
sha256sum deploy-sim opt/deployctl-2.4.1/bin/deployctl opt/deployctl-$OLD/bin/deployctl > .lm/hashes
echo "$OLD" > .lm/old
exit 0
