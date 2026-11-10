# Offline Docs

## Why it works
`wget -r` reads each page it downloads and fetches what it links to.
`-np` stopped it from following the links to /blog/, /admin/ and the site
root, and robots.txt (which wget honours by default when crawling) kept it out
of /docs/old/. `-nH --cut-dirs=1` turned
`127.0.0.1:PORT/docs/guide/x.html` into `guide/x.html`, and `-k` rewrote
`/docs/guide/x.html` into relative links such as `../guide/x.html`, while links
to pages it did not download became full URLs. Without `-k` an offline copy
looks fine in `ls` but every link points to a server that no longer exists.

## Common mistakes
- Forgetting `-np`: the crawl climbs into the parent directory and collects the whole site.
- Adding `-e robots=off` to "get everything": you mirror what the owner asked crawlers to skip.
- Running wget again on top of a bad try: it keeps the old files (and adds `index.html.1` style copies).

## Learn next
`wget -m` (= `-r -N -l inf`) re-runs a mirror and only fetches changed files.
`-p` gets page requisites (CSS, images) even from other directories, `-E`
adds `.html` to pages served without it, and `-R 'pattern'` / `--exclude-directories`
skip parts of a site.
