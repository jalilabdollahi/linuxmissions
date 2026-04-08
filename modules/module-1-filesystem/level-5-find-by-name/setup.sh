#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX"/{project-a/src,project-b/lib,project-c/tests}
touch "$SANDBOX/project-a/src/main.py"
touch "$SANDBOX/project-a/src/utils.py"
touch "$SANDBOX/project-b/lib/helper.py"
touch "$SANDBOX/project-c/tests/test_core.py"
touch "$SANDBOX/project-c/tests/test_api.py"
# Red herrings
touch "$SANDBOX/project-a/src/main.js"
touch "$SANDBOX/project-b/lib/readme.md"
