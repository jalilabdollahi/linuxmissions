# Which Upload Limit?

## Why it works
In nginx a directive applies to the block it is written in and everything nested
below it, and an inner value overrides an outer one. So the value for the whole
`uploads.example.com` vhost is the one written directly in its `server { }`; the
one inside `location /api` only affects that path, and the one in `http { }`
is the fallback for vhosts that set nothing. Finding the right block first
(`server_name`), then reading by indentation, beats counting 40 identical lines.

## Common mistakes
- Taking the first `client_max_body_size` after the server_name: it can be a comment.
- Taking the value of the `location` block, or the vhost that proxies *to* uploads.example.com.
- Searching for the directive across the whole file and picking by luck.

## Next step
`nginx -T` prints the complete effective configuration on a real server, and
`less +/pattern file` opens the pager already at the first match.
