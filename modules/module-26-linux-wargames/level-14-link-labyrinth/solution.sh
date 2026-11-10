#!/bin/bash
new=$(ls deploy/releases | sort -V | tail -1)
cd deploy
ln -sfn "releases/$new" current
ln -sfn "../releases/$new/bin/app" bin/app
ln -sfn storage/logs logs
rm shared/uploads shared/uploads.current
ln -s ../storage/uploads shared/uploads
rm config/active.conf
ln -s "../releases/$new/app.conf" config/active.conf
cd ..
find -L deploy -type l
ls -l deploy deploy/shared deploy/config
