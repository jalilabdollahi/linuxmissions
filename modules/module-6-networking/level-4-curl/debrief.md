# API Call

## Why it works
HTTP APIs usually authenticate each request with a header. `curl -H
"X-API-Key: ..."` adds it, and the server answers 200 with the JSON instead of
401. Piping into `jq -r '.service.status'` walks the JSON structure, so it
picks the right `"status"` among several and prints it without quotes. Text
tools like grep would match the first `"status"` they see, which may belong to
a different object.

## Common mistakes
- Ignoring the status code: with `-s` a 401 error body looks like any other
  JSON. `curl -sS -f` makes curl exit non-zero on HTTP errors, and
  `-w '%{http_code}\n'` prints the code.
- Putting the key in the URL (`?key=...`) when the API expects a header. URLs
  end up in logs and shell history; headers usually don't.

## Learn next
`curl -sS -o body.json -w '%{http_code}\n' URL` saves the body and prints only
the status code, which is the classic health-check one-liner. For POST
requests: `curl -X POST -H 'Content-Type: application/json' -d '{"a":1}' URL`.
