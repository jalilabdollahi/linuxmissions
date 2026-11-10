# Reformatted and Tweaked

## Why it works
`diff` is exact by default, so re-indentation hides the real change under hundreds of
noise lines. `-w` makes whitespace irrelevant and `-B` ignores blank-line changes; what
remains is the semantic difference: `maxconn 2000 -> 200`, a different balance algorithm
and the retry count. A reviewer who only skims a 300-line diff would miss the one that
could cut capacity by ten.

## Common mistakes
- `diff -b` instead of `-w`: it ignores changes in the *amount* of whitespace but not whitespace
  that is added where there was none.
- Listing lines instead of directive names, or listing a directive that only moved.
- Trusting the formatting commit message: "small tweaks" included a 10x drop of maxconn.

## Next step
`git diff --ignore-all-space` does the same for repositories, and `diff -y -W 160`
shows old and new side by side.
