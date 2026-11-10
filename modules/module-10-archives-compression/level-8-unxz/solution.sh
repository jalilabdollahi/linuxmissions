#!/bin/bash
xz -l exports/*.xz
xz -l --robot exports/*.xz | awk '$1 == "totals" {print $5}' > total_bytes.txt
cat total_bytes.txt
unxz -k exports/customers.sql.xz
ls -l exports
