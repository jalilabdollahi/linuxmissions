#!/bin/bash
# Runs gen_vhost.sh for two domains it has not seen and compares both files
# with the examples (DOMAIN and PORT swapped in), checks the generated script
# with bash -n and runs it against a mock curl. Bad arguments must exit 2 and
# write nothing.
SANDBOX="$1"
SCRIPT="$SANDBOX/gen_vhost.sh"
EX="$SANDBOX/examples"

if [ ! -f "$SCRIPT" ]; then
  echo "❌ gen_vhost.sh is missing (type reset to get it back)"
  exit 1
fi
if [ ! -f "$EX/shop.example.com.conf" ] || [ ! -f "$EX/shop.example.com-healthcheck.sh" ]; then
  echo "❌ the files in examples/ are missing or renamed (type reset)"
  exit 1
fi

WORK="$(mktemp -d "$SANDBOX/.check.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
LIMIT=""
command -v timeout >/dev/null 2>&1 && LIMIT="timeout 5"

mkdir -p "$WORK/mockbin"
cat > "$WORK/mockbin/curl" <<'MOCK'
#!/bin/bash
printf '%s\n' "$@" > "$CURL_LOG"
exit "${CURL_EXIT:-0}"
MOCK
chmod +x "$WORK/mockbin/curl"

# expect EXAMPLE DOMAIN PORT OUT: the example with the name and port swapped
expect() {
  local text
  text="$(cat "$1")"
  text="${text//shop.example.com/$2}"
  text="${text//8081/$3}"
  printf '%s\n' "$text" > "$4"
}

# first_diff A B: the first differing line of B, for the message
first_diff() {
  diff "$1" "$2" | grep '^>' | head -1 | cut -c3-
}

n=0
for pair in "api.internal.test 9300" "status-$(( RANDOM % 900 + 100 )).example.org $(( RANDOM % 2000 + 7000 ))"; do
  set -- $pair
  domain="$1"; port="$2"; n=$((n + 1))
  R="$WORK/run$n"
  mkdir -p "$R"
  cp "$SCRIPT" "$R/gen_vhost.sh"
  (cd "$R" && $LIMIT bash ./gen_vhost.sh "$domain" "$port" </dev/null >/dev/null 2>"$R/.err")
  code=$?
  conf="$R/sites/$domain.conf"
  hc="$R/sites/$domain-healthcheck.sh"
  if [ "$code" != 0 ]; then
    echo "❌ ./gen_vhost.sh $domain $port failed (status $code): $(head -1 "$R/.err")"
    exit 1
  fi
  for f in "$conf" "$hc"; do
    if [ ! -f "$f" ]; then
      echo "❌ ./gen_vhost.sh $domain $port did not write sites/${f##*/}"
      exit 1
    fi
  done

  expect "$EX/shop.example.com.conf" "$domain" "$port" "$WORK/want.conf"
  if ! cmp -s "$WORK/want.conf" "$conf"; then
    if grep -Eq 'Host ;|X-Real-IP ;|For ;' "$conf"; then
      echo "❌ in sites/$domain.conf the nginx variables (\$host, \$remote_addr, ...) came out empty: bash expanded them while writing the file"
    elif grep -q '\$domain\|\$port' "$conf"; then
      echo "❌ sites/$domain.conf still contains a literal \$domain or \$port instead of the values"
    else
      echo "❌ sites/$domain.conf differs from the example; first wrong line: $(first_diff "$WORK/want.conf" "$conf")"
    fi
    exit 1
  fi

  expect "$EX/shop.example.com-healthcheck.sh" "$domain" "$port" "$WORK/want.sh"
  if ! cmp -s "$WORK/want.sh" "$hc"; then
    if grep -q '\$domain\|\$port' "$hc"; then
      echo "❌ sites/$domain-healthcheck.sh still contains \$domain or \$port: those must be filled in when the file is written"
    elif grep -q 'path="\${1:-/healthz}"' "$hc"; then
      echo "❌ sites/$domain-healthcheck.sh differs from the example; first wrong line: $(first_diff "$WORK/want.sh" "$hc")"
    else
      echo "❌ in sites/$domain-healthcheck.sh the script's own \$1, \$path and \$url must stay literal; first wrong line: $(first_diff "$WORK/want.sh" "$hc")"
    fi
    exit 1
  fi
  if [ ! -x "$hc" ]; then
    echo "❌ sites/$domain-healthcheck.sh is not executable"
    exit 1
  fi
  if ! bash -n "$hc" 2>/dev/null; then
    echo "❌ bash -n finds a syntax error in sites/$domain-healthcheck.sh"
    exit 1
  fi
  out="$(cd "$R" && CURL_LOG="$R/curl.log" PATH="$WORK/mockbin:$PATH" $LIMIT "$hc" /status 2>/dev/null)"
  if [ "$out" != "OK http://127.0.0.1:$port/status" ] ||
     [ "$(tr '\n' ' ' < "$R/curl.log")" != "-fsS -o /dev/null -H Host: $domain http://127.0.0.1:$port/status " ]; then
    echo "❌ running sites/$domain-healthcheck.sh /status did not check http://127.0.0.1:$port/status with Host: $domain"
    exit 1
  fi
  if (cd "$R" && CURL_LOG="$R/curl.log" CURL_EXIT=7 PATH="$WORK/mockbin:$PATH" $LIMIT "$hc" >/dev/null 2>&1); then
    echo "❌ sites/$domain-healthcheck.sh exits 0 even when curl fails"
    exit 1
  fi
done

# Bad arguments: usage on stderr, exit 2, no files.
for args in "" "only.example.net" "web.example.net http"; do
  R="$WORK/bad"
  rm -rf "$R"; mkdir -p "$R"
  cp "$SCRIPT" "$R/gen_vhost.sh"
  (cd "$R" && $LIMIT bash ./gen_vhost.sh $args </dev/null >"$R/.out" 2>"$R/.err")
  code=$?
  shown="./gen_vhost.sh${args:+ $args}"
  if [ "$code" != 2 ]; then
    echo "❌ '$shown' exits with status $code, expected 2 (usage error)"
    exit 1
  fi
  if [ ! -s "$R/.err" ]; then
    echo "❌ '$shown' should print a usage message on stderr"
    exit 1
  fi
  if [ -n "$(find "$R" -name '*.conf' -o -name '*healthcheck*')" ]; then
    echo "❌ '$shown' is rejected but still writes files"
    exit 1
  fi
done

echo "✅ gen_vhost.sh fills in DOMAIN and PORT and keeps every \$ that belongs to nginx or to the generated script"
exit 0
