#!/bin/bash
# all.yaml: "---", 14 documents separated by "---", and at the end a "---"
# followed by a comment line. Each document is also saved under .lm-state/docs/.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state/docs
rm -f .lm-state/docs/*
pick() { shuf -n "$1" -e "${@:2}"; }
names=($(shuf -e web api cart auth search mailer billing reports cache queue gateway worker ledger media))
port() { echo $((3000 + RANDOM % 5000)); }
doc() {  # doc <kind> <name>
  local kind=$1 name=$2 f=.lm-state/docs/$(echo "$1" | tr 'A-Z' 'a-z')-$2.yaml
  case $kind in
    Deployment) cat > "$f" <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $name
  namespace: prod
spec:
  replicas: $((1 + RANDOM % 5))
  template:
    spec:
      containers:
      - name: $name-main
        image: registry.local/$name:$((1 + RANDOM % 9)).$((RANDOM % 30))
        ports:
        - containerPort: $(port)
      - name: sidecar
        image: registry.local/proxy:1.$((RANDOM % 9))
YAML
    ;;
    Service) cat > "$f" <<YAML
apiVersion: v1
kind: Service
metadata:
  name: $name
  namespace: prod
spec:
  selector:
    app: $name
  ports:
  - name: http
    port: 80
    targetPort: $(port)
YAML
    ;;
    ConfigMap) cat > "$f" <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: $name
  namespace: prod
data:
  name: $name-settings
  LOG_LEVEL: $(pick 1 info debug warn)
  POOL_SIZE: "$((4 + RANDOM % 60))"
YAML
    ;;
    CronJob) cat > "$f" <<YAML
apiVersion: batch/v1
kind: CronJob
metadata:
  name: $name
  namespace: prod
spec:
  schedule: "$((RANDOM % 60)) $((RANDOM % 24)) * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: job
            image: registry.local/jobs:$((1 + RANDOM % 9))
YAML
    ;;
    Ingress) cat > "$f" <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $name
  namespace: prod
spec:
  rules:
  - host: $name.shop.example.org
    http:
      paths:
      - path: /
        backend:
          service:
            name: $name
YAML
    ;;
  esac
}
# 14 documents: kinds spread over the 14 distinct names, kind-name pairs are unique
kinds=(Deployment Service ConfigMap CronJob Ingress Deployment Service ConfigMap Deployment Service ConfigMap Ingress CronJob Deployment)
for i in $(seq 0 13); do doc "${kinds[i]}" "${names[i]}"; done
order=($(ls .lm-state/docs | shuf))
{
  echo "---"
  last=$((${#order[@]} - 1))
  for i in "${!order[@]}"; do
    cat ".lm-state/docs/${order[i]}"
    [ "$i" -lt "$last" ] && echo "---"
  done
  echo "---"
  echo "# end of export, ${#order[@]} resources"
} > all.yaml
