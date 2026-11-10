# A Prompt That Tells the Truth

## Why it works
Readline decides where to put the cursor from the length of the prompt. Colour escape sequences have bytes
but no width, so they must sit between `\[` and `\]`; otherwise a long command wraps onto its own prompt and
editing the line corrupts the display. A static PS1 cannot know the last exit code, so a function in
`PROMPT_COMMAND` rebuilds PS1 before every prompt: its first line saves `$?`, because the next command would
overwrite it.

## Common mistakes
- Colour codes outside `\[ \]`: the prompt looks fine until a command is longer than the line.
- Reading `$?` after another command in PROMPT_COMMAND (for example after `history -a`): it then reports that command's status.
- Showing `0` on success: the point is that a number appears only when something failed.

## Next step
`echo "${PS1@P}"` prints the prompt as bash would draw it, and `tput setaf 1` / `tput sgr0` are the portable way to
produce colour sequences if you do not want to hard-code escapes.
