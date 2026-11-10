#!/bin/bash
file outbox/ledger-2025.tar.bz2
tar -cjf outbox/ledger-2025.tar.bz2 ledger
bzip2 -k audit.log
mv audit.log.bz2 outbox/
file outbox/*.bz2
