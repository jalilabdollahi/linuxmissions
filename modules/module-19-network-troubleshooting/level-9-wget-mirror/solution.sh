#!/bin/bash
wget -q -r -np -nH --cut-dirs=1 -k -P mirror "$(cat docs-url.txt)"
find mirror -type f | sort
