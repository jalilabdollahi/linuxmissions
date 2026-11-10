# Answer The Wizard Without A Human

## Why it works
A program that asks questions needs a conversation, not a pile of answers.
`coproc` starts the wizard in the background with two pipes: the script reads
its output from `${W[0]}` and writes answers to `${W[1]}`. The prompts end in
`: ` with no newline, so `read -d ':'` splits the stream at the colon instead of
waiting for a line end. A `case` on the prompt text picks the value from
`answers.conf`, whatever the order. `-t` stops the script from waiting forever
if the wizard never asks, and when the wizard exits `read` fails and the loop
ends.

## Common mistakes
- A here-doc of answers (`./provision-wizard <<< ...`) works only for the
  order it was written for; the wizard rejects an answer to the wrong
  question.
- `read line` without `-d`: the prompt has no newline, so it blocks.
- Matching words that appear in more than one prompt, so the wrong answer is sent.

## Learn next
`mkfifo in out` gives the same two-way pipe with named files, and `expect`
(not installed here) is the full-featured tool for this job.
