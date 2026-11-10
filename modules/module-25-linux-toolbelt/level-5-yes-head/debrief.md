# Unattended Installer, Thousand Pings

## Why it works
`yes` writes its argument (default `y`) and a newline over and over, as fast as
the reader can take it. The installer reads one line per question, so a pipe
from `yes` answers however many questions there are. When the installer
exits, the pipe closes and `yes` receives SIGPIPE and stops. The same
mechanism ends `yes ping | head -n 1000`: `head` quits after 1000 lines and
that closes the pipe behind it.

## Common mistakes
- `yes ping > load.txt` with no `head`: it never stops and fills the disk
  until you press Ctrl-C.
- `echo y | ./install.sh`: one answer only; the second question reads end of
  input, which the installer counts as "no".
- `./install.sh < /dev/null` or an empty line: both mean "N".

## Learn next
Many installers and package tools have their own flags (`apt-get -y`,
`rm -f`, `ssh-keygen -N ''`), which are better than `yes` when they exist.
For a fixed block of answers a here-document (`<<EOF`) is the other option.
