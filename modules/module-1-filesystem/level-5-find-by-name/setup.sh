#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p project-a/src/api project-a/tests project-b/lib project-b/docs \
         project-c/scripts project-c/.venv/lib/site-packages/requests \
         project-c/tools.py

# 19 Python files
for f in project-a/src/main.py project-a/src/config.py project-a/src/api/__init__.py \
         project-a/src/api/routes.py project-a/src/api/auth.py \
         project-a/tests/test_routes.py project-a/tests/test_auth.py project-a/tests/conftest.py \
         project-b/lib/helpers.py project-b/lib/parser.py "project-b/lib/data loader.py" \
         project-b/setup.py \
         project-c/scripts/backup.py project-c/scripts/cleanup.py project-c/scripts/migrate_db.py \
         project-c/.venv/lib/site-packages/requests/__init__.py \
         project-c/.venv/lib/site-packages/requests/api.py \
         project-c/.venv/lib/site-packages/six.py \
         project-c/manage.py; do
  printf '# %s\nprint("hello")\n' "$f" > "$f"
done

# Things that are not Python files
printf 'console.log("hi")\n' > project-a/src/main.js
printf '# Project B\n' > project-b/docs/readme.md
printf 'old setup\n' > project-b/setup.py.bak
printf '\x00\x01compiled' > project-b/lib/parser.pyc
printf '#!/bin/sh\n' > project-c/tools.py/run.sh      # tools.py is a directory
printf 'requests==2.31\n' > project-c/requirements.txt
