#!/bin/bash
# Part 1: culprit.txt / when.txt are compared with the deletion inside the
# window on the incident date. Part 2: .bashrc is loaded by a clean
# interactive bash (in a scratch HOME, so the real history file is untouched).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
HIST=home/deploy/.bash_history

if [ ! -f "$HIST" ] || [ ! -f INCIDENT.txt ] || [ ! -f home/deploy/.bashrc ]; then
  echo "❌ a level file is missing (INCIDENT.txt, .bash_history or .bashrc); type reset to start over"
  exit 1
fi
utc() { date -u -d "@$1" '+%F %T' 2>/dev/null || date -u -r "$1" '+%F %T'; }
day="$(sed -n 's/^Date: *//p' INCIDENT.txt)"

# The deletion inside the window: the find ... -delete between 02:10 and 02:25 on $day.
want_cmd=""; want_when=""
while IFS= read -r line; do
  case "$line" in
    '#'[0-9]*) t="${line#\#}"; continue ;;
  esac
  when="$(utc "$t")"
  case "$when" in
    "$day 02:1"[0-9]*|"$day 02:2"[0-4]*)
      case "$line" in *-delete*) want_cmd="$line"; want_when="$when" ;; esac ;;
  esac
done < "$HIST"
if [ -z "$want_cmd" ]; then
  echo "❌ the history file was changed; type reset to start over"
  exit 1
fi

clean() { tr -d '\r' < "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'; }

if [ ! -s culprit.txt ]; then
  echo "❌ culprit.txt does not exist yet (or is empty)"
  exit 1
fi
got_cmd="$(clean culprit.txt)"
if [ "$got_cmd" != "$want_cmd" ]; then
  case "$got_cmd" in
    *'rm -rf /srv/app/tmp'*) echo "❌ culprit.txt names the rm -rf, but check its timestamp: it ran before the window" ;;
    D=*) echo "❌ culprit.txt holds the assignment; which command then used \$D to delete files?" ;;
    *) echo "❌ culprit.txt does not hold the command that deleted the uploads, exactly as written in the history" ;;
  esac
  exit 1
fi

if [ ! -s when.txt ]; then
  echo "❌ when.txt does not exist yet (or is empty)"
  exit 1
fi
got_when="$(clean when.txt | sed -e 's/T/ /' -e 's/ *UTC$//' -e 's/Z$//')"
if [ "$got_when" != "$want_when" ]; then
  case "$got_when" in
    "$day "*) echo "❌ when.txt has '$got_when', which is not when that command ran on $day (in UTC)" ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]) echo "❌ when.txt has the wrong date: the same command also ran another night, outside the incident" ;;
    *) echo "❌ when.txt should hold one UTC time as YYYY-MM-DD HH:MM:SS, it has '$got_when'" ;;
  esac
  exit 1
fi

# Part 2: the shell settings.
WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp home/deploy/.bashrc "$WORK/.bashrc"
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"
out="$(cd "$WORK" && $LIMIT env -i HOME="$WORK" PATH="$PATH" TERM=dumb HISTFILE="$WORK/hist" bash -i -c '
  printf "fmt=%s\nsize=%s\nfilesize=%s\nctl=%s\n" "$HISTTIMEFORMAT" "$HISTSIZE" "$HISTFILESIZE" "$HISTCONTROL"
  shopt -q histappend && echo append=on' </dev/null 2>/dev/null)"
get() { printf '%s\n' "$out" | sed -n "s/^$1=//p" | tail -1; }
num() { case "$1" in ''|*[!0-9]*) echo 0 ;; *) echo "$1" ;; esac; }

if [ -z "$(get fmt)" ]; then
  echo "❌ a new shell for deploy still has no HISTTIMEFORMAT, so history shows no times"
  exit 1
fi
if [ "$(num "$(get size)")" -lt 10000 ] || [ "$(num "$(get filesize)")" -lt 10000 ]; then
  echo "❌ HISTSIZE is '$(get size)' and HISTFILESIZE is '$(get filesize)'; both must be at least 10000"
  exit 1
fi
if [ "$(get append)" != on ]; then
  echo "❌ histappend is off: each shell that exits overwrites the history file with its own list"
  exit 1
fi
case ":$(get ctl):" in
  *ignorespace*|*ignoreboth*) echo "❌ HISTCONTROL='$(get ctl)' still drops commands that start with a space"; exit 1 ;;
esac

echo "✅ found it ($want_when UTC) and deploy's history is now large, timestamped and appended"
exit 0
