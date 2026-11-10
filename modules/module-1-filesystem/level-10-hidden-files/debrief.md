# Secrets in Plain Sight

## Why it works
A leading dot is the only thing that makes a file "hidden": `ls` skips those
names unless you add `-a`. Programs use this to keep their settings out of the
way (`.bashrc`, `.ssh/`, `.config/`). `find` and `grep -r` do not skip dotfiles,
so `find . -name '.*' -type f` would have listed `.credentials` directly.

## Common mistakes
- Taking the value from `.env.example`: example files ship with placeholders.
- Copying the whole file or line into token.txt: tools that read the token expect
  only the value, and the rest leaks extra data.
- `ls -a *` does not help: the `*` glob itself skips dotfiles.

## Learn next
`ls -A` shows hidden entries but not `.` and `..`. In bash, `shopt -s dotglob`
makes `*` match dotfiles too. Never commit files like `.credentials` or `.env`:
add them to `.gitignore`.
