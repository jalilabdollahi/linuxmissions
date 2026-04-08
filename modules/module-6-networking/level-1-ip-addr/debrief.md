# What's My IP?

## What you practiced
`ip addr` output combines interface metadata with assigned addresses. Text tools help turn that raw output into a compact inventory.

## Commands to remember
```bash
ip addr
awk '/^[0-9]+:/ {iface=$2} /inet / {print iface, $2}'
grep -A1 'inet '
```
