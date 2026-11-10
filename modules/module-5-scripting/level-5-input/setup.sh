#!/bin/bash
SANDBOX="$1"

# The last line deliberately has no trailing newline.
printf '%s\n' \
  '# app.env - deploy settings, exported by load_env.sh' \
  '# Values are plain text from the settings form: never execute them.' \
  '' \
  'APP_NAME=linuxmissions' \
  'APP_ENV=staging' \
  'APP_PORT=8080' \
  'APP_TITLE=Linux Missions (staging)' \
  '' \
  '# database' \
  'DATABASE_URL=postgres://app:s3cret@db.internal:5432/missions?sslmode=require' \
  'MOTD=Deployed by $(whoami) on $(hostname)' > "$SANDBOX/app.env"
printf '%s' 'LOG_LEVEL=info' >> "$SANDBOX/app.env"

cat > "$SANDBOX/load_env.sh" <<'SCRIPT'
#!/bin/bash
# Usage: source load_env.sh FILE
# Export every KEY=value line of FILE. Values are text: never run them.
# TODO
SCRIPT

chmod +x "$SANDBOX/load_env.sh"
