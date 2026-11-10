#!/bin/bash
# Disk at 92%: eleven rotated logs to gzip, the live log and .1 must stay put.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p logs .lm-state

# write_log FILE DATE SEED: one day of web shop log lines (random, so the
# content cannot be guessed back after compression).
write_log() {
  awk -v day="$2" -v seed="$3" 'BEGIN {
    srand(seed)
    split("GET GET GET POST GET PUT DELETE", m, " ")
    split("/ /cart /checkout /api/items /api/items/42 /login /static/app.js /search?q=bike", u, " ")
    split("200 200 200 200 304 302 404 500", s, " ")
    n = 2500 + int(rand() * 1500)
    for (i = 0; i < n; i++) {
      t = int(i * 86400 / n)
      printf "%s %02d:%02d:%02d %s %s %s %dms req=%08x\n", day, t/3600, (t%3600)/60, t%60,
        m[1+int(rand()*7)], u[1+int(rand()*8)], s[1+int(rand()*8)], 3+int(rand()*900), int(rand()*4294967295)
    }
  }' > "$1"
}

write_log logs/app.log 2026-11-10 "$RANDOM"
for n in $(seq 1 14); do
  if [ "$n" -le 9 ]; then d=$(printf '2026-11-%02d' $(( 10 - n ))); else d="2026-10-$(( 41 - n ))"; fi
  write_log "logs/app.log.$n" "$d" "$RANDOM$n"
done
gzip -9 logs/app.log.13 logs/app.log.14

# Reference data for the validator: content checksums and the live files' inodes.
for n in $(seq 2 12); do
  echo "$n $(cksum < "logs/app.log.$n")" >> .lm-state/rotated.sums
done
for f in app.log app.log.1 app.log.13.gz app.log.14.gz; do
  echo "$f $(ls -i "logs/$f" | awk '{print $1}') $(cksum < "logs/$f")" >> .lm-state/keep.sums
done
