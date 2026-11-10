#!/bin/bash
# Reference solution: write load_env.sh with a heredoc, then try it.
cat > load_env.sh <<'EOF'
#!/bin/bash
# Usage: source load_env.sh FILE
while IFS='=' read -r key value || [ -n "$key" ]; do
  case "$key" in
    ''|'#'*) continue ;;
  esac
  export "$key=$value"
done < "$1"
EOF
source load_env.sh app.env
echo "$APP_TITLE"
