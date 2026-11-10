#!/bin/bash
# Range from the 8443 listen line to the block's closing brace at column 0 (^}),
# and inside that range append after the marker line. Portable (GNU and BSD sed).
sed '/listen 8443/,/^}/{
/# EXTRA CONFIG/a\
    include /etc/myapp/extra.conf;
}' app.conf > app.conf.new && mv app.conf.new app.conf
cat app.conf
