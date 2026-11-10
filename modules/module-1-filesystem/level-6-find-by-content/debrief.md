# The Password Leak

## Why it works
`grep -r` reads every file under the starting folder, hidden ones included, and
`-l` stops at the first match in each file and prints only its name. That gives
one path per line, the list a security team needs. Matching `password=` also
catches `db_password=` and `--password=`, which a search for a whole word would miss.

## Common mistakes
- Forgetting `-l`: you get `file:matching line`, which copies the secrets into
  your report.
- `grep -r password` (without `=`) also flags harmless lines such as
  `password_min_length=12` and prompts like `password: `.

## Learn next
`grep -rn` adds line numbers, `-i` ignores case (to catch `PASSWORD=` too), and
`--include='*.conf'` or `--exclude-dir=.git` limits which files are searched.
Real projects use scanners like gitleaks, but they work on the same idea.
