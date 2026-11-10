#!/bin/bash
# Start as `player`. When HOST_UID/HOST_GID are given (./play.sh --docker),
# give `player` the host user's ids so progress.json in the mounted repo stays
# owned by the host user.
set -e
if [ "$(id -u)" = 0 ]; then
  uid="${HOST_UID:-1000}"
  gid="${HOST_GID:-1000}"
  [ "$gid" != "$(id -g player)" ] && groupmod -o -g "$gid" player
  [ "$uid" != "$(id -u player)" ] && usermod -o -u "$uid" player
  chown -R player: /home/player
  exec setpriv --reuid=player --regid=player --init-groups \
    env HOME=/home/player USER=player LOGNAME=player "$@"
fi
exec "$@"
