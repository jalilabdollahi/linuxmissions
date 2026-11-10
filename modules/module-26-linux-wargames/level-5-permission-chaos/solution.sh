#!/bin/bash
setfacl --restore=perms.acl
find app -newer perms.acl -type d -exec chmod 2750 {} +
find app -newer perms.acl -type f -exec chmod 640 {} +
find app -newer perms.acl -type f -path '*/bin/*' -exec chmod 750 {} +
find app -newer perms.acl -type f -path '*/secrets/*' -exec chmod 600 {} +
