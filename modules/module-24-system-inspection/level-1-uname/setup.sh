#!/bin/bash
# The player fills in facts.env from the live `uname`. Nothing is random
# because the answer is the sandbox machine itself.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
cat > TICKET.md <<'T'
# Vendor case 88213: kernel details required

Support will not look at the NIC firmware problem until we tell them:

  - the kernel name
  - the kernel release (the short version string, e.g. 6.8.0-45-generic)
  - the machine hardware name (the CPU architecture)

Take them from the machine itself, not from a wiki page: the answer must
match what this box reports right now. Put them in facts.env.
T
cat > facts.env <<'T'
# Facts for vendor case 88213. One KEY=value per line, no spaces around '='.
KERNEL_NAME=
KERNEL_RELEASE=
ARCH=
T
