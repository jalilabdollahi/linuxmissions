#!/bin/bash
SANDBOX="$1"
W="$SANDBOX/webroot"
mkdir -p "$W/static/css" "$W/static/js" "$W/static/img" "$W/pages/blog"
echo "<html>Home</html>"                  > "$W/index.html"
echo "<html>About</html>"                 > "$W/pages/about.html"
echo "<html>Contact</html>"               > "$W/pages/contact.html"
echo "<html>Launch day</html>"            > "$W/pages/blog/launch day.html"
echo "body{margin:0}"                     > "$W/static/css/style.css"
echo "console.log('hello')"               > "$W/static/js/app.js"
printf 'JPEGDATA'                         > "$W/static/img/team photo.jpg"
echo "Options -Indexes"                   > "$W/.htaccess"

# The restore made everything private...
find "$W" -type d -exec chmod 700 {} +
find "$W" -type f -exec chmod 600 {} +
# ...except one page someone already "fixed" with 777
chmod 777 "$W/pages/contact.html"
