#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/deploy.sh" << 'SCRIPT'
#!/bin/bash
# Release helper: records what was deployed next to this script.
cd "$(dirname "$0")" || exit 1
{
  echo "Deployment successful"
  echo "Version: 1.4.2"
  echo "Started as: $0"
} > output.txt
echo "deploy.sh: wrote output.txt"
SCRIPT
chmod 644 "$SANDBOX/deploy.sh"   # readable, but nobody may execute it
