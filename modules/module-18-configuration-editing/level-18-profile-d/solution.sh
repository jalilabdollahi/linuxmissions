#!/bin/bash
# A POSIX sh drop-in: test the directory, test PATH as ":$PATH:" so only a whole element matches.
cat > etc/profile.d/tool.sh <<'SH'
# vendor tool: add its bin directory once, and only if it exists
tool_dir="$SANDBOX/opt/tool/bin"
if [ -d "$tool_dir" ]; then
  case ":$PATH:" in
    *":$tool_dir:"*) ;;
    *) PATH="$PATH:$tool_dir" ;;
  esac
fi
export PATH
unset tool_dir
SH
rm -f etc/profile.d/tool.conf
sh -c '. etc/profile.d/tool.sh; . etc/profile.d/tool.sh; echo "$PATH"'
