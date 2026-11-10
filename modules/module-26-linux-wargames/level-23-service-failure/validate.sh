#!/bin/bash
SB="$1"; cd "$SB" || exit 1
export LM_ROOT="$SB"
SC="$SB/bin/systemctl"
PORT=$(cat .lm/port); LPORT=$(cat .lm/legacy.port); LPID=$(cat .lm/legacy.pid)
if [ "$("$SC" is-active legacy 2>/dev/null)" != "active" ] || [ "$("$SC" show -P MainPID legacy 2>/dev/null)" != "$LPID" ] || ! curl -fs "http://127.0.0.1:$LPORT/health" 2>/dev/null | grep -q 'legacy ok'; then
  echo "❌ the legacy service is no longer the same running process on its own port: it must not be disturbed"; exit 1; fi
if [ "$("$SC" is-active webapp 2>/dev/null)" != "active" ]; then echo "❌ webapp is not active (systemctl status webapp and journalctl -u webapp say why)"; exit 1; fi
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$PORT/health" 2>/dev/null)
if [ "$code" != "200" ]; then echo "❌ webapp is active but http://127.0.0.1:$PORT/health answers $code, not 200"; exit 1; fi
"$SC" restart webapp >/dev/null 2>&1
sleep 1.5
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$PORT/health" 2>/dev/null)
if [ "$("$SC" is-active webapp 2>/dev/null)" != "active" ] || [ "$code" != "200" ]; then echo "❌ webapp works only until a restart: the fix is not in the unit configuration"; exit 1; fi
if [ "$("$SC" is-active legacy 2>/dev/null)" != "active" ]; then echo "❌ the legacy service stopped"; exit 1; fi
echo "✅ webapp serves /health on port $PORT after a restart, and legacy was left alone"
