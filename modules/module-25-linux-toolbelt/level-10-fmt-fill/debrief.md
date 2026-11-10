# Reflow the Release Notes

## Why it works
`fmt` treats a paragraph as a run of lines with the same indentation, ended
by a blank line or by a line indented differently. It joins the words of a
paragraph and breaks them again at the width you give (`-w 72`), and it keeps
the paragraph's indentation, so the indented bullet list comes out indented. The
blank lines between items are what keep each paragraph and each bullet a unit
of its own. `fold` never joins anything, which is why it could not do this job.

## Common mistakes
- No `-w`: the default width is 75, over the limit.
- Piping through `tr '\n' ' '` first: every paragraph and bullet becomes one blob.
- Bullets with no blank line between them (`- a` directly above `- b`) have the
  same indentation, so `fmt` would join them into one paragraph; here they are
  separated, but real notes often are not, and then a blank line has to be
  added first (or the job done with awk).
- `fmt` puts two spaces after a sentence that ends a line; `-u` makes spacing
  uniform.

## Learn next
`fmt -s` only splits long lines and never joins (a gentler `fold -s`), and
`fmt -p '# '` reflows a block of comments while keeping the `# ` prefix.
