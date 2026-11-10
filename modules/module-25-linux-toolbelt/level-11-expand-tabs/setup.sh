#!/bin/bash
# deploy.yaml: a Deployment whose indentation was typed with tabs, with a mix
# of "N tabs", "space + tabs" and "tab + spaces" forms for the same level, and
# two real tabs inside quoted values.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

app=$(printf '%s\n' shop billing search auth mailer reports | awk -v s="$RANDOM$$" 'BEGIN{srand(s)} {a[NR]=$0} END{print a[1+int(rand()*NR)]}')
T=$'\t'
line() {  # line <level> <text>
  local n=$1 text=$2 v=$((RANDOM % 4)) i pre=""
  if [ "$n" -gt 0 ]; then
    if [ $v -eq 1 ]; then pre=" $T"; for ((i = 1; i < n; i++)); do pre="$pre$T"; done
    elif [ $v -eq 2 ] && [ "$n" -ge 2 ]; then pre="$T"; for ((i = 1; i < n; i++)); do pre="$pre  "; done
    else for ((i = 0; i < n; i++)); do pre="$pre$T"; done; fi
  fi
  printf '%s%s\n' "$pre" "$text"
}
{
  line 0 "apiVersion: apps/v1"
  line 0 "kind: Deployment"
  line 0 "metadata:"
  line 1 "name: $app"
  line 1 "labels:"
  line 2 "app: $app"
  line 2 "tier: backend"
  line 0 "spec:"
  line 1 "replicas: $((2 + RANDOM % 5))"
  line 1 "selector:"
  line 2 "matchLabels:"
  line 3 "app: $app"
  line 1 "template:"
  line 2 "metadata:"
  line 3 "labels:"
  line 4 "app: $app"
  line 2 "spec:"
  line 3 "containers:"
  line 3 "- name: $app"
  line 4 "image: registry.local/$app:$((1 + RANDOM % 9)).$((RANDOM % 20))"
  line 4 "ports:"
  line 5 "- containerPort: $((8000 + RANDOM % 900))"
  line 4 "env:"
  line 5 "- name: LOG_LEVEL"
  line 6 "value: info"
  line 5 "- name: BANNER"
  line 6 "value: \"ready${T}steady\""
  line 5 "- name: MESSAGE"
  line 6 "value: \"col1${T}col2${T}col3\""
  line 4 "resources:"
  line 5 "limits:"
  line 6 "memory: ${RANDOM:0:2}0Mi"
  line 6 "cpu: \"$((1 + RANDOM % 4))00m\""
} > deploy.yaml
# the two quoted values carry a tab that must survive
cp deploy.yaml deploy.yaml.orig
cp deploy.yaml .lm-state/deploy.orig
