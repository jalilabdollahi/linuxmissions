#!/bin/bash
# suspicious.cron: three normal entries and one that decodes and runs a blob.
# The blob is the payload wrapped three times: standard base64, then gzip, then
# base64url without padding. The payload only prints text (inert).
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state
tok() { LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "$1"; }
host="$(tok 4)-$(tok 3).$(tok 6).example.invalid"
drop="/var/tmp/.$(tok 5)/$(tok 4)d"
pad=0
while :; do
  payload=$(printf '#!/bin/sh\n# training stub: only prints, runs nothing\necho "[stage2] contacting https://%s/q/%s"\necho "[stage2] writing %s"\necho "[stage2] adding persistence"\n%s' \
    "$host" "$(tok 6)" "$drop" "$(printf '# %*s' "$pad" '' | tr ' ' '.')")
  blob=$(printf '%s\n' "$payload" | base64 -w0 | gzip -9n | base64 -w0 | tr '+/' '-_' | tr -d '=')
  # the trap needs padding to be missing and both url-safe characters to occur
  if [ $((${#blob} % 4)) -ne 0 ] && [[ $blob == *-* ]] && [[ $blob == *_* ]]; then break; fi
  pad=$((pad + 1))
done
{
  echo "# m h dom mon dow user command"
  echo "17 3 * * * root /usr/sbin/logrotate /etc/logrotate.conf"
  echo "*/15 * * * * www-data /usr/bin/php /var/www/cron.php"
  echo "*/$((3 + RANDOM % 9)) * * * * root echo $blob | base64 -d | sh"
  echo "0 4 * * 0 root /usr/bin/apt-get -qq update"
} > suspicious.cron
printf 'c2=%s\ndropped=%s\n' "$host" "$drop" > .lm-state/expected
