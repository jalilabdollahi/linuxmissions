# Template Engine

## Why it works
`source ./vars.env` sets the three variables in the running script. In
`cat > app.conf <<EOF`, the end word is unquoted, so bash expands `$APP_NAME`
and friends inside the text before handing it to `cat`. A backslash in front of
`$` (`\$remote_addr`) switches expansion off for that one character, which is
how a template keeps the `$` signs another program (here the web server's log
format) needs.

You also used the opposite case: writing generate.sh from the prompt with
`<<'SCRIPT'`. The quoted end word means "copy every character as typed", so the
`$APP_NAME` inside reached the file unexpanded.

## Common mistakes
- Using `<<'EOF'` for the template: the config then contains the literal text
  `$APP_NAME` instead of the value.
- Indenting the closing `EOF`: the end word must be alone at the start of the
  line (only `<<-EOF` allows leading tabs).

## Learn next
`envsubst` (from gettext) fills `$VARS` into a template file, and
`envsubst '$APP_NAME $APP_PORT'` limits it to the variables you list, so other
`$` signs survive. `printf` with a format string is another way to build
small files.
