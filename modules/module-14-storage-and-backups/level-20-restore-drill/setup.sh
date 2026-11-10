#!/bin/bash
# projects/ as it is on Tuesday evening: after Monday's backup (backups/projects-mon.tar.gz,
# plus an older Sunday one) somebody ran an rm that removed several files and a whole
# directory; meanwhile other files were edited and a couple of new ones created.
# Deleted files have modes that a umask would change (664, 660) and old mtimes.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state backups
umask 022
W=$(mktemp -d "$SANDBOX/.lm-state/build.XXXXXX") || exit 1
trap 'rm -rf "$W"' EXIT
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }

mkdir -p "$W/projects"
cd "$W" || exit 1
declare -A MODE
files=(
  "projects/website/index.html:664" "projects/website/css/site.css:664" "projects/website/js/app.js:644"
  "projects/website/img/hero banner.txt:660" "projects/api/server.py:755" "projects/api/config.yaml:640"
  "projects/api/tests/test_orders.py:664" "projects/api/tests/test_users.py:664" "projects/notes/todo.md:664"
  "projects/notes/meeting 2026-10-28.md:660" "projects/notes/.private:600" "projects/data/export.csv:644"
  "projects/data/export-old.csv:644" "projects/legacy/build.sh:750" "projects/legacy/README:664"
  "projects/legacy/src/main.c:664" "projects/legacy/src/util.c:664"
)
i=0
for e in "${files[@]}"; do
  p=${e%:*}; m=${e##*:}; i=$((i + 1))
  mkdir -p "$(dirname "$p")"
  echo "content of $p, revision $RANDOM" > "$p"; head -c $((100 + RANDOM % 900)) /dev/urandom | base64 >> "$p"
  chmod "$m" "$p"
  touch -d "2026-10-$(printf '%02d' $((1 + i))) $(printf '%02d:%02d:%02d' $((8 + RANDOM % 9)) $((RANDOM % 60)) $((RANDOM % 60)))" "$p"
done
# Sunday's backup: older, with a different version of one file that was changed on Monday
cp "projects/api/config.yaml" "$W/config.monday"
echo "retries: 1  # sunday version" > projects/api/config.yaml; touch -d "2026-10-30 09:00:00" projects/api/config.yaml; chmod 640 projects/api/config.yaml
tar -czf "$SANDBOX/backups/projects-sun.tar.gz" projects
cp "$W/config.monday" projects/api/config.yaml; touch -d "2026-11-02 10:15:00" projects/api/config.yaml; chmod 640 projects/api/config.yaml
tar -czf "$SANDBOX/backups/projects-mon.tar.gz" projects

# Tuesday: edits, new files, and the accidental rm
edited=("projects/website/index.html" "projects/api/server.py" "projects/notes/todo.md" "projects/legacy/README")
for p in "${edited[@]}"; do echo "tuesday edit $RANDOM" >> "$p"; touch -d "2026-11-03 $(printf '%02d:%02d:00' $((9 + RANDOM % 8)) $((RANDOM % 60)))" "$p"; done
newf=("projects/notes/tuesday-ideas.md" "projects/api/tests/test_billing.py")
for p in "${newf[@]}"; do echo "new on tuesday $RANDOM" > "$p"; chmod 664 "$p"; touch -d "2026-11-03 15:30:00" "$p"; done
deleted=("projects/website/css/site.css" "projects/website/img/hero banner.txt" "projects/api/config.yaml"
         "projects/notes/meeting 2026-10-28.md" "projects/notes/.private" "projects/api/tests/test_users.py")
for p in "${deleted[@]}"; do rm -f "$p"; done
rm -rf projects/legacy/src projects/data/export-old.csv

# expected final state: path <TAB> mode <TAB> mtime <TAB> sha256
exp() {  # tree-root-relative file
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}
mkdir -p "$W/mon" && tar -xzf "$SANDBOX/backups/projects-mon.tar.gz" -C "$W/mon" --no-same-permissions 2>/dev/null
mkdir -p "$W/mon2" && ( umask 000; tar -xzpf "$SANDBOX/backups/projects-mon.tar.gz" -C "$W/mon2" )
: > "$SANDBOX/.lm-state/expect.tsv"
# files of Monday's backup: edited ones keep Tuesday's state, everything else is the backup's
while IFS= read -r -d '' f; do
  src="$W/mon2/$f"
  for e in "${edited[@]}"; do [ "$e" = "$f" ] && src="$W/$f"; done
  printf '%s\t%s\t%s\t%s\n' "$f" "$(stat -c %a "$src")" "$(stat -c %Y "$src")" "$(sha256sum < "$src" | cut -d' ' -f1)"
done < <(cd "$W/mon2" && find projects -type f -print0) >> "$SANDBOX/.lm-state/expect.tsv"
for p in "${newf[@]}"; do printf '%s\t%s\t%s\t%s\n' "$p" "$(stat -c %a "$p")" "$(stat -c %Y "$p")" "$(sha256sum < "$p" | cut -d' ' -f1)"; done >> "$SANDBOX/.lm-state/expect.tsv"
LC_ALL=C sort -o "$SANDBOX/.lm-state/expect.tsv" "$SANDBOX/.lm-state/expect.tsv"
( cd "$W/mon2" && find projects -type d | LC_ALL=C sort ) > "$SANDBOX/.lm-state/dirs"
printf '%s\n' "${deleted[@]}" "projects/legacy/src/main.c" "projects/legacy/src/util.c" "projects/data/export-old.csv" | LC_ALL=C sort -u > "$SANDBOX/.lm-state/restored"
mv projects "$SANDBOX/projects"
cd "$SANDBOX" || exit 1
cat > TICKET.txt <<'EOT'
Tuesday, 16:40: someone ran an rm in projects/ and took out several files and a
whole directory. Monday's nightly backup is backups/projects-mon.tar.gz (the
Sunday one is older, do not use it).

Bring back everything that was deleted, as it was in Monday's backup: same
content, same permissions, same modification times. But people have been working
since Monday: files that still exist (edited today or not) must be left exactly
as they are now, and nothing that was not in the backup may appear. New files
made today stay.
EOT
