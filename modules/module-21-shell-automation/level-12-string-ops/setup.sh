#!/bin/bash
# parse_artifact.sh splits names with cut/sed/basename, which do not exist on
# the release bot's bare runner, and cuts at the first hyphen anyway. The
# validator runs it with PATH=/nonexistent, so only bash built-ins work.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p dist

cat > parse_artifact.sh <<'EOF'
#!/bin/bash
# parse_artifact.sh FILE - print the parts of a release artifact name:
#   dist/log-shipper-2.4.1-linux-amd64.tar.gz
#   -> name=log-shipper version=2.4.1 os=linux arch=amd64 ext=tar.gz
# Format: NAME-VERSION-OS-ARCH.EXT (a leading directory is ignored)
#   NAME     lowercase letters, digits and hyphens, starting with a letter or digit
#   VERSION  three numbers: MAJOR.MINOR.PATCH
#   OS, ARCH lowercase letters and digits
#   EXT      tar.gz, tar.xz or zip
# Anything else: "parse_artifact: not an artifact name: FILE" on stderr, exit 1.
# Runs on the release bot's minimal runner: bash only, no other programs.

file=$(basename "$1")
name=$(echo "$file" | cut -d- -f1)
version=$(echo "$file" | cut -d- -f2)
os=$(echo "$file" | cut -d- -f3)
arch=$(echo "$file" | cut -d- -f4 | sed 's/\..*//')
ext=$(echo "$file" | sed 's/^[^.]*\.//')
echo "name=$name version=$version os=$os arch=$arch ext=$ext"
EOF
chmod +x parse_artifact.sh

for f in log-shipper-2.4.1-linux-amd64.tar.gz log-shipper-2.4.1-darwin-arm64.tar.gz \
         log-shipper-2.4.1-windows-amd64.zip k8s-node-agent-0.19.0-linux-arm64.tar.xz \
         checksums.txt; do
  : > "dist/$f"
done

cat > RUNNER.txt <<'EOF'
The release bot runs steps in a minimal container: /bin/bash and nothing
else on PATH (no cut, sed, awk, basename, grep). Its log for last release:

  $ ./parse_artifact.sh dist/log-shipper-2.4.1-linux-amd64.tar.gz
  ./parse_artifact.sh: line 13: basename: command not found
  ./parse_artifact.sh: line 14: cut: command not found
  ./parse_artifact.sh: line 15: cut: command not found
  ./parse_artifact.sh: line 16: cut: command not found
  ./parse_artifact.sh: line 17: cut: command not found
  ./parse_artifact.sh: line 17: sed: command not found
  ./parse_artifact.sh: line 18: sed: command not found
  name= version= os= arch= ext=

Try the same here with:  env -i PATH=/nonexistent /bin/bash ./parse_artifact.sh dist/log-shipper-2.4.1-linux-amd64.tar.gz
EOF
