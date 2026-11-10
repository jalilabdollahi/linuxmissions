#!/bin/bash
{
  echo "owner=$(jq -r '.meta.owner.contacts[] | select(.type == "email") | .value' data.json)"
  echo "active=$(jq -r '[.services[] | select(.status.active == true) | .name] | join(",")' data.json)"
} > report.txt
cat report.txt
