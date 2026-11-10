#!/bin/bash
SANDBOX="$1"
A="$SANDBOX/app"
mkdir -p "$A/config" "$A/data" "$A/scripts"

put() {  # put MODE PATH CONTENT
  printf '%s\n' "$3" > "$A/$2"
  chmod "$1" "$A/$2"
}

# fine as they are
put 644 config/db.conf        "host=db1"
put 755 scripts/start.sh      "#!/bin/sh"
put 664 data/shared.csv       "id,owner"        # group-writable on purpose
put 640 config/secrets.env    "TOKEN=abc"

# world-writable (others have w)
put 666 config/app.conf       "debug=false"
put 777 data/cache.dat        "cache"
put 666 data/session.dat      "sessions"
put 646 data/.lock            "1234"            # hidden
put 777 "scripts/run backup.sh" "#!/bin/sh"     # space in the name
put 662 config/feature_flags  "beta=on"         # group read+write, others write only
