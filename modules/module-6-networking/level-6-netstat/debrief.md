# Connection Map

## What you practiced
Connection tables can answer higher-level questions like “how many distinct clients are connected?” once you extract and aggregate the right field.

## Commands to remember
```bash
ss -tn
awk '$1=="ESTAB" {print $5}'
sort -u
uniq
```
