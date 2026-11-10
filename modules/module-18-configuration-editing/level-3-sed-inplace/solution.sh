#!/bin/bash
# Restrict the substitution to the staging section and to the real port line.
sed -i.bak '/^\[staging\]/,/^\[/ s/^port = 8080$/port = 9080/' services.conf
diff services.conf.bak services.conf
