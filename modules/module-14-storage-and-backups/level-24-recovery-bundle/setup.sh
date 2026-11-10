#!/bin/bash
# box/ is the server's root as far as the bundle is concerned. bundle.list names what the
# on-call engineer needs; several entries are symlinks (the target must be shipped, under
# the link's name), one name has a space, one file is ~22-25 MB so that the bundle
# does not fit one 20,000,000-byte part. disk.img is a GPT disk with three partitions.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state out
pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
b=box
mkdir -p $b/etc/nginx/sites-available $b/etc/nginx/sites-enabled $b/etc/ssh $b/etc/cron.d $b/etc/ssl/private \
         $b/run/systemd/resolve $b/opt/shop/shared $b/var/lib/shop $b/root $b/srv/www
w() { echo "$2" > "$b/$1"; head -c $((200 + RANDOM % 800)) /dev/urandom | base64 >> "$b/$1"; }
w etc/nginx/nginx.conf "worker_processes $((1 + RANDOM % 8));"
w etc/nginx/sites-available/shop.conf "server_name shop$RANDOM.example.org;"
w etc/nginx/sites-available/staging.conf "server_name staging$RANDOM.example.org;"
ln -s ../sites-available/shop.conf $b/etc/nginx/sites-enabled/shop.conf
ln -s ../sites-available/staging.conf $b/etc/nginx/sites-enabled/staging.conf
w etc/ssh/sshd_config "Port $((20000 + RANDOM % 9000))"
w "etc/cron.d/nightly backup" "30 2 * * * root /usr/local/bin/backup.sh"
w run/systemd/resolve/stub-resolv.conf "nameserver 10.$((RANDOM % 250)).0.2"
ln -s ../run/systemd/resolve/stub-resolv.conf $b/etc/resolv.conf
w opt/shop/shared/app.ini "[app]\nsecret=$RANDOM"
ln -s ../opt/shop/shared/app.ini $b/etc/shop-app.ini
w root/.bashrc "export PS1='dr# '"
w etc/ssl/private/README "keys are not part of the bundle"
w srv/www/index.html "<h1>$RANDOM</h1>"
head -c $((22000000 + RANDOM * 100)) /dev/urandom > $b/var/lib/shop/state.db
cat > $b/etc/fstab <<EOT
# /etc/fstab for shop-01
UUID=$(cat /proc/sys/kernel/random/uuid) /          ext4  errors=remount-ro 0 1
UUID=$(cat /proc/sys/kernel/random/uuid) /boot/efi  vfat  umask=0077        0 1
UUID=$(cat /proc/sys/kernel/random/uuid) none       swap  sw                0 0
LABEL=DATA /var/lib/shop ext4 defaults,noatime 0 2
EOT

# the list: paths relative to box/, one per line; the ones that are links need their target
cat > bundle.list <<'EOT'
etc/nginx/nginx.conf
etc/nginx/sites-enabled/shop.conf
etc/nginx/sites-enabled/staging.conf
etc/ssh/sshd_config
etc/cron.d/nightly backup
etc/resolv.conf
etc/shop-app.ini
root/.bashrc
var/lib/shop/state.db
EOT

truncate -s 24M disk.img
printf 'label: gpt\nsize=%dMiB, type=U, name="efi"\nsize=%dMiB, type=L, name="root"\nsize=%dMiB, type=S, name="swap"\n' \
  $((2 + RANDOM % 4)) $((6 + RANDOM % 4)) $((3 + RANDOM % 3)) | sfdisk -q disk.img || exit 1
sfdisk -d disk.img | sed -E '/^device:/d; s#^[^ ]+([0-9]+) : #p\1 : #' > .lm-state/table.norm
stat -c %s disk.img > .lm-state/disk-size

cat > TICKET.txt <<'EOT'
On-call disaster-recovery bundle for shop-01

Build the bundle from the server tree in box/ (its "/") and put it in out/.

1. Content. A directory named dr-bundle containing exactly:
     files/<path>      every path listed in bundle.list (paths relative to
                       box/, one per line, names may contain spaces). If a listed
                       path is a symbolic link, ship what it points to, as a
                       regular file under the link's own name. No links in the bundle.
     fstab             a copy of box/etc/fstab
     disk.sfdisk       the partition-table dump of disk.img (the output of the
                       tool that makes dumps sfdisk can read back)
     MANIFEST.sha256   sha256 sums of every other file in dr-bundle, in
                       sha256sum format, with paths relative to dr-bundle, so that
                       'cd dr-bundle && sha256sum -c MANIFEST.sha256' works
                       after extraction
2. Packaging. dr-bundle packed as a gzip-compressed tar archive, cut into
   parts of AT MOST 20,000,000 bytes (that is the limit of the transfer tool)
   named out/dr-bundle.tgz.part-aa, -ab, ... in order.
3. out/SHA256SUMS: sha256sum of every part (format: hash, two spaces, file
   name only), so that 'cd out && sha256sum -c SHA256SUMS' works.
out/ must contain only the parts and SHA256SUMS.

The checker will do what the on-call engineer does: join the parts, check the
sums, extract, verify the manifest, compare every file with the server tree
and rebuild the partition table on a blank image from your dump.
EOT
