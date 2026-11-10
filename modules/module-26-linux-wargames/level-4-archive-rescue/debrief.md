# Archive Rescue

## Why it works
`part.*` sorts as text: 1, 10, 11, 12, 2, ... so a plain `cat part.*` builds a
corrupt archive. Joining by a numeric loop (or `sort -V`) fixes the order, and
using the re-sent copy of the damaged part fixes the content; the vendor's hash
of `dataset.tar.gz` proves both. Extracting by member path (`tar -xzf FILE -C
restored dataset/reports`) takes only what was asked for and never touches the
`../../evil.sh` member: never unpack an archive from outside blindly, list it
first with `tar -tzf`. GNU tar refuses `..` members by default, but other
tools do not.

## Common mistakes
- Extracting everything and deleting what you did not need: the hostile member
  and the other folders have already been written.
- Trusting the join because `tar` did not complain about the first few members.
- Hashing the archive but not the extracted files.

## Next step
`split -d -a 2 -b 10M file part.` creates numbered parts whose names do sort
correctly; `tar --wildcards` and `tar -t` are worth knowing for selective restores.
