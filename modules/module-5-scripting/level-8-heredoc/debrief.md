# Template Engine

## What you practiced
Heredocs are a clean way to generate multi-line files from shell variables. They are especially handy for configs, manifests, and small templates.

## Commands to remember
```bash
source ./vars.env

cat > app.conf <<EOF
name=$APP_NAME
port=$APP_PORT
environment=$APP_ENV
EOF
```
