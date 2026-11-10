#!/bin/bash
# Take an exclusive, non-blocking flock on a lock file next to the script,
# right after the cd. The kernel drops the lock when the process dies, even
# after kill -9, so there is nothing stale to clean up.
awk '{ print } /^cd /{ print "exec 9> sync.lock"; print "flock -n 9 || { echo \"sync.sh: another sync is running, not starting\" >&2; exit 1; }" }' sync.sh > .sync.new && cat .sync.new > sync.sh && rm .sync.new
