# One Site per File

## Why it works
Config blocks nest, so "up to the first `}`" is wrong; the end of a block is where
the brace depth returns to zero. awk keeps a counter across lines, collects the
block text in a variable and, when the depth is 0, writes it to a file whose name
came from the block's own first `server_name` line. Only the first name is used
(`shop.example.com` with two aliases becomes one file), and braces inside comments
are ignored so they cannot confuse the counter.

## Common mistakes
- Splitting with `csplit` on `^server` and naming the files `xx00`, `xx01`: the names must come from the content.
- Cutting at the first `}`: the `location` blocks end up in the next file.
- Using the last or the second `server_name` word, or writing `server_name` including the `;`.

## Next step
`csplit -z -f part- sites.conf '/^server/' '{*}'` splits at every pattern match,
and `nginx -t` (on a real host) confirms the files still parse once included.
