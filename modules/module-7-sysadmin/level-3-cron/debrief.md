# Scheduled Sweep

## What you practiced
Cron expressions are compact but powerful. Once you know the five time fields, recurring jobs become easy to encode.

## Commands to remember
```bash
crontab -l
0 3 * * * /path/to/cleanup.sh
*/5 * * * * /path/to/check.sh
```
