#!/bin/bash
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p bin sbin lib etc share/doc "opt/backup" srv/team

mk() {  # mk MODE PATH
  printf '#!/bin/sh\necho %s\n' "$(basename "$2")" > "$2"
  chmod "$1" "$2"
}

# ordinary files
mk 755 bin/ls-wrapper
mk 755 bin/ordinary
mk 644 lib/libfoo.so
mk 644 etc/config.conf
mk 644 share/doc/suid_audit_notes.txt     # the name is not the bit
mk 777 bin/world_writable_tool             # bad, but not SUID/SGID
# a setgid DIRECTORY (normal for team folders; not a file)
chmod 2775 srv/team
mk 644 srv/team/report.txt

# macOS gives files in /tmp the group 'wheel'; switch to your own group so
# the SGID bits below are allowed (no-op on Linux)
chgrp -R "$(id -g)" "$SANDBOX" 2>/dev/null

# planted files
mk 4755 bin/special_tool                  # SUID
mk 2755 bin/group_tool                    # SGID
mk 6755 sbin/.dbus-helper                 # SUID+SGID, hidden
mk 4750 "opt/backup/run backup"           # SUID, space in the name
mk 4644 lib/libcrypt.so.1                 # SUID without execute (shows as S)
