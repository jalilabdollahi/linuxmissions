#!/bin/bash
snap="backups/config-$(date +%Y%m%d)-$(tr -d '\r' < VERSION)"
cp -r config "$snap"
ls backups | cat -v
