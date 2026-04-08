# Secrets in Plain Sight

## What you practiced
- Files and directories starting with `.` are hidden from plain `ls` but not from `ls -a`
- `find` shows hidden files by default — it doesn't skip dotfiles
- Dotfiles like `.bashrc`, `.gitconfig`, `.ssh/config` are standard Linux config locations

## Important note
Never store real secrets in dotfiles tracked by git (`.env`, `.credentials`). Use `.gitignore` and proper secrets management.

## Commands to remember
```bash
ls -la                          # show all including hidden
ls -la ~/.config/               # inspect config dotfiles
find ~ -name ".*" -type f       # find all hidden files in home
cat ~/.bashrc                   # shell config
cat ~/.gitconfig                # git config
```
