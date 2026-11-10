#!/bin/bash
# Reference solution: rewrite deploy.sh around one function.
cat > deploy.sh <<'EOF'
#!/bin/bash
# deploy.sh - ship every service from build/ to releases/

deploy_service() {
  local name="$1"
  echo "==> Deploying $name"
  cp "build/$name.tar" "releases/$name.tar"
  echo "$name ready"
}

deploy_service api
deploy_service web
deploy_service worker
EOF
