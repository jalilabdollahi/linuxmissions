# DRY Deploy

## What you practiced
Functions keep scripts maintainable by turning repeated logic into named building blocks. `local` variables help avoid accidental reuse across the whole script.

## Commands to remember
```bash
deploy_service() {
  local name="$1"
  echo "Deploying $name"
}

deploy_service api
echo $?
```
