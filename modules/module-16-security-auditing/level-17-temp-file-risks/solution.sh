#!/bin/bash
sed -i 's|^tmp=.*|tmp=$(mktemp "${TMPDIR:-/tmp}/report.XXXXXX")|' nightly-report.sh
sed -i "/^set -e/a trap 'rm -f \"\$tmp\"' EXIT" nightly-report.sh
sed -i '/^rm -f "\$tmp"$/d' nightly-report.sh
cat nightly-report.sh
