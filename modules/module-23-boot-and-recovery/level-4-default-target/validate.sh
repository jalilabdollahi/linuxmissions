#!/bin/bash
# default.target must be a symlink whose literal target is the multi-user unit
# as seen on the booted machine (absolute /usr/lib or /lib form).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
R=sysroot
L=$R/etc/systemd/system/default.target

if ! ( cd $R/usr/lib/systemd/system 2>/dev/null && cksum *.target ssh.service ) 2>/dev/null | cmp -s - .lm-state/units; then
  echo "❌ a unit file under sysroot/usr/lib/systemd/system was changed; the fix is the symlink, not the units"
  exit 1
fi
if [ ! -L "$L" ]; then
  if [ -e "$L" ]; then
    echo "❌ default.target is a regular file now; it must be a symlink to the unit"
  else
    echo "❌ sysroot/etc/systemd/system/default.target is missing"
  fi
  exit 1
fi
T=$(readlink "$L")
case "$T" in
  /usr/lib/systemd/system/multi-user.target|/lib/systemd/system/multi-user.target)
    ;;
  "$SANDBOX"/*|*sysroot*)
    echo "❌ the link points at '$T', a path in this rescue system; on the booted server that path does not exist (link as the server sees it, from its own /)"
    exit 1 ;;
  */graphical.target|graphical.target)
    echo "❌ default.target still points at graphical.target"
    exit 1 ;;
  */rescue.target|*/emergency.target)
    echo "❌ default.target points at '$T': that is a recovery mode, not the normal boot target"
    exit 1 ;;
  /*)
    echo "❌ the link points at '$T', which is not the multi-user.target unit file"
    exit 1 ;;
  *)
    echo "❌ the link target '$T' is relative; use the absolute path the server will see (starting with /usr/lib)"
    exit 1 ;;
esac
if ! ls -l $R/etc/systemd/system/multi-user.target.wants | cmp -s - .lm-state/wants; then
  echo "❌ multi-user.target.wants was changed; leave the enabled services alone"
  exit 1
fi
echo "✅ default.target -> $T, as the booted server will read it"
exit 0
