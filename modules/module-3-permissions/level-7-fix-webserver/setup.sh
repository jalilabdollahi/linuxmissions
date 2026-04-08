#!/bin/bash
SANDBOX="$1"
mkdir -p "$SANDBOX/webroot/static/css" "$SANDBOX/webroot/static/js" "$SANDBOX/webroot/pages"
echo "<html>Home</html>" > "$SANDBOX/webroot/index.html"
echo "<html>About</html>" > "$SANDBOX/webroot/pages/about.html"
echo "body{}" > "$SANDBOX/webroot/static/css/style.css"
echo "console.log('hello')" > "$SANDBOX/webroot/static/js/app.js"

# Break permissions (webserver can't read)
chmod 700 "$SANDBOX/webroot"
chmod 700 "$SANDBOX/webroot/static"
chmod 700 "$SANDBOX/webroot/pages"
chmod 600 "$SANDBOX/webroot/index.html"
chmod 600 "$SANDBOX/webroot/pages/about.html"
chmod 600 "$SANDBOX/webroot/static/css/style.css"
chmod 600 "$SANDBOX/webroot/static/js/app.js"
