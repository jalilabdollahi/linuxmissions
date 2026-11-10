#!/bin/bash
# After the Failed Deploy: a capistrano-style releases/ tree. Symlinks point to
# files, to directories (they look like folders in ls) and to nothing. Some
# directories are empty, others hold only a hidden .gitkeep or an empty subdir,
# and there are zero-byte files that -empty also matches.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
R=releases
mkdir -p $R/shared/config $R/shared/log $R/shared/uploads/avatars $R/shared/node_modules

printf 'DB_HOST=db-01\nDB_POOL=10\n' > $R/shared/config/app.env
printf 'workers: 4\n' > $R/shared/config/sidekiq.yml
printf 'GET / 200\n' > $R/shared/log/production.log
printf 'PNG' > $R/shared/uploads/avatars/u1.png

for rel in 20261108-0912 20261109-1544; do
  d=$R/$rel
  mkdir -p $d/app/models $d/app/views $d/config $d/public/assets $d/tmp/cache $d/storage/cache
  printf 'class User; end\n' > $d/app/models/user.rb
  printf '<h1>home</h1>\n' > $d/app/views/index.html
  printf 'app.css\napp.js\n' > $d/public/assets/manifest.txt
  printf '%s\n' "$rel" > $d/REVISION
  : > $d/storage/cache/.gitkeep
  ln -s ../../shared/config/app.env $d/config/app.env
  ln -s ../../shared/log $d/log
  ln -s ../../../shared/uploads $d/public/uploads
done
rmdir $R/20261108-0912/tmp/cache   # leaves tmp/ empty in the old release

# The half-finished release.
d=$R/20261110-0230
mkdir -p $d/app/models $d/app/views $d/config $d/public/assets/fonts $d/tmp/pids \
         $d/storage/cache $d/vendor/bundle "$d/public/system/print queue"
printf 'class User; end\n' > $d/app/models/user.rb
: > $d/storage/cache/.gitkeep
: > $d/deploy.lock
: > $d/app/views/index.html.partial
ln -s ../../shared/config/app.env $d/config/app.env
ln -s ../../shared/config/app.env.new $d/config/app.env.next   # dangling
ln -s ../../shared/node_modules $d/node_modules

ln -s 20261110-0230 $R/current
ln -s 20261109-1544 $R/previous
