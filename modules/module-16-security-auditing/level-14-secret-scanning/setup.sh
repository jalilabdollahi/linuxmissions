#!/bin/bash
# repo/ is about to go public. Eight real (fake-valued) credentials are hidden at random
# line numbers among placeholders and look-alikes:
#   AWS key in an env file and in a python module, a private key block, password
#   assignments in prod.ini (password=), mail.conf (PASSWORD=) and .git-old/config
#   (password = ...), a ghp_ token in a script and one inside a .log.gz.
# Decoys: AWS's documented AKIAIOSFODNN7EXAMPLE, empty/<placeholder>/${VAR} passwords,
# password_* keys, a public key, a redacted token. expected = "file:line" per leak.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
rm -rf repo leaks.txt .lm-state; mkdir -p .lm-state repo/{config,deploy/keys,docs,src/legacy,scripts,logs,.git-old}
: > .lm-state/expected

up()  { head -c 200 /dev/urandom | od -An -tx1 | tr -d ' \n' | tr 'a-f' 'A-F' | cut -c1-"$1"; }
low() { head -c 200 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-"$1"; }
alnum() { LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"; }

# put FILE LEAK-TEXT < filler lines : inserts the leak at a random position, records file:line
put() {
  local f=$1 leak=$2 L pos i
  mapfile -t L
  pos=$((RANDOM % (${#L[@]} + 1)))
  { for ((i = 0; i < pos; i++)); do printf '%s\n' "${L[i]}"; done
    printf '%s\n' "$leak"
    for ((i = pos; i < ${#L[@]}; i++)); do printf '%s\n' "${L[i]}"; done; } > "$f"
  echo "$f:$((pos + 1))" >> .lm-state/expected
}

cat > repo/README.md <<'DOC'
# billing-sync

Syncs invoices to the data warehouse. See docs/setup.md.

Example credentials in the AWS docs look like this (they are public documentation values):

    aws_access_key_id = AKIAIOSFODNN7EXAMPLE
    aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

Never commit real ones.
DOC
cat > repo/docs/setup.md <<'DOC'
# Setup

1. Copy `.env.example` to `.env` and fill it in.
2. `export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE` is the documented placeholder, use your own.
3. The database password comes from `password=${DB_PASSWORD}` in config/dev.ini.
4. To find leftovers before a release run: `grep -ri password config/`
DOC
cat > repo/.env.example <<'DOC'
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
password=<your-password-here>
token=<redacted>
DOC
cat > repo/config/dev.ini <<'DOC'
[database]
host = localhost
password=${DB_PASSWORD}
password_min_length = 12
[cache]
password=
DOC
cat > repo/deploy/keys/id_deploy.pub <<DOC
-----BEGIN PUBLIC KEY-----
$(alnum 48)
-----END PUBLIC KEY-----
DOC
cat > repo/logs/app.log <<'DOC'
2024-03-02 10:00:01 INFO sync started token=<redacted>
2024-03-02 10:00:09 INFO 214 invoices exported
DOC

put repo/config/prod.ini "password=Pr0d-$(alnum 10)" <<'DOC'
[database]
host = db.internal
port = 5432
user = billing
# password rotation: every 90 days
password_min_length = 16
[cache]
host = cache.internal
DOC
put repo/config/mail.conf "PASSWORD=Smtp-$(alnum 9)" <<'DOC'
# outgoing mail
server = smtp.internal
port = 587
starttls = yes
DOC
put repo/deploy/aws.env "AWS_ACCESS_KEY_ID=AKIA$(up 16)" <<'DOC'
AWS_DEFAULT_REGION=eu-west-1
S3_BUCKET=billing-exports
DOC
put repo/src/legacy/upload.py "KEY = \"AKIA$(up 16)\"" <<'DOC'
import sys
BUCKET = "billing-exports"
def upload(path):
    print("uploading", path)
DOC
put repo/scripts/release.sh "export GH_TOKEN=ghp_$(alnum 36)" <<'DOC'
#!/bin/bash
set -e
VERSION=$1
git tag "v$VERSION"
DOC
put repo/deploy/keys/old-deploy.pem "-----BEGIN OPENSSH PRIVATE KEY-----
$(alnum 64)
$(alnum 64)
-----END OPENSSH PRIVATE KEY-----" <<'DOC'
# rotated 2023-11, kept for the audit
# fingerprint in docs/keys.txt
DOC
put repo/.git-old/config "	password = Git-$(alnum 12)" <<'DOC'
[core]
	repositoryformatversion = 0
[remote "origin"]
	url = https://git.internal/billing-sync.git
[credential]
	helper = store
DOC

# the gz leak: line number inside the decompressed log
put repo/logs/app-2024-03.log.tmp "2024-03-01 02:14:09 DEBUG retry with token=ghp_$(alnum 36)" <<'DOC'
2024-03-01 02:14:01 INFO sync started
2024-03-01 02:14:02 INFO fetching invoices
2024-03-01 02:14:05 WARN upstream slow, retrying
2024-03-01 02:14:30 INFO 198 invoices exported
2024-03-01 02:14:31 INFO sync finished
DOC
sed -i 's#^repo/logs/app-2024-03.log.tmp:#repo/logs/app-2024-03.log.gz:#' .lm-state/expected
gzip -n -c repo/logs/app-2024-03.log.tmp > repo/logs/app-2024-03.log.gz; rm -f repo/logs/app-2024-03.log.tmp
gzip -n -c repo/logs/app.log > repo/logs/app-2024-02.log.gz   # clean old log

LC_ALL=C sort -u .lm-state/expected -o .lm-state/expected
find repo -type f | LC_ALL=C sort | xargs sha256sum > .lm-state/tree.sha
