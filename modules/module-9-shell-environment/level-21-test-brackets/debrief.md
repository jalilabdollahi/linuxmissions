# Gatekeeper

## Why it works
`[` is a command like any other, so its arguments go through word splitting
and globbing first. An empty `$DEPLOY_ENV` vanished (`[ != staging ]`), a value
with spaces became several words (`too many arguments`), and the unquoted
`*-rc*` was matched against file names. On such errors `[` returns 2, and an
`if [ ... ]; then stop; fi` treats 2 just like "false": the check silently
passed. `[ -n $X ]` with X unset is `[ -n ]`, a one-argument test that is
always true.

`[[ ]]` is part of bash's grammar: variables inside it are neither split nor
globbed, `==` with an unquoted right side is a pattern match, and `=~` matches
an extended regular expression. Anchors (`^...$`) make the format exact, which
the loose glob `[0-9]*.[0-9]*.[0-9]*` was not (`*` happily matched " beta").

## Common mistakes
- `[[ $RELEASE =~ "^v?[0-9]+..." ]]`: quoting the regex makes bash compare
  the literal characters, so nothing ever matches. Leave it unquoted or put it
  in a variable: `re='^v?...$'; [[ $RELEASE =~ $re ]]`.
- Quoting the right side of `==` when you want a pattern: `[[ $X == "prod-*" ]]`
  only matches the text `prod-*` itself.
- `[ $a == $b ]` in scripts run by sh (dash): `==` is a bash extension there.

## Learn next
`BASH_REMATCH` holds the regex groups after a successful `=~`
(`${BASH_REMATCH[1]}`). For portable `sh` scripts, quote every variable in
`[ ]` and use `case "$X" in prod-*) ...` for patterns. `shellcheck guard.sh`
finds most of these bugs automatically.
