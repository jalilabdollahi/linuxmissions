#!/bin/bash
SANDBOX="$1"

cat > "$SANDBOX/process.sh" <<'SCRIPT'
#!/bin/bash
# Crunches today's data (slowly), then writes result.txt next to itself.
cd "$(dirname "$0")" || exit 1
rm -f result.txt
for step in 1 2 3 4 5 6 7 8 9 10; do
  sleep 1
done
echo "done: 10/10 batches processed by PID $$" > result.txt
SCRIPT
chmod +x "$SANDBOX/process.sh"
