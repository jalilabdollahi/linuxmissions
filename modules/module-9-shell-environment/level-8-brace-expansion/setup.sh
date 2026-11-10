#!/bin/bash
# Scaffolding: 12 month dirs + 3x2x2 service dirs, and a backup of config.yaml.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

cat > config.yaml <<'EOF'
# metrics-svc configuration
service: metrics-svc
storage:
  root: ./data
  layout: "{year}/{month}"      # month is two digits: 01..12
  retention_months: 13
components:
  - name: api
    port: 8080
  - name: web
    port: 8081
  - name: worker
    concurrency: 4
stages: [dev, prod]
EOF

cat > CHECKLIST.txt <<'EOF'
metrics-svc storage checklist
[ ] data/2026/<MM>                          MM = 01 .. 12
[ ] svc/<component>/<stage>/conf            component: api web worker
[ ] svc/<component>/<stage>/logs            stage: dev prod
[ ] config.yaml.bak (identical copy, made BEFORE editing config.yaml)
EOF
