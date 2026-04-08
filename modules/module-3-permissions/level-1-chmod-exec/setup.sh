#!/bin/bash
SANDBOX="$1"
cat > "$SANDBOX/deploy.sh" << 'EOF'
#!/bin/bash
echo "Deployment successful" > "$(dirname "$0")/output.txt"
echo "Version: 1.0.0" >> "$(dirname "$0")/output.txt"
EOF
chmod 644 "$SANDBOX/deploy.sh"  # readable but not executable
