# Secret Hunt

## Why it works
A secret is a string, and a string leaves one trace per transformation it went
through. `grep -rIF` covers plain text (hidden files included); compressed
copies need `zgrep`; tar members need `tar -xzOf archive member | grep`;
Kubernetes Secrets store values in base64, so you search for the base64 of the
key; and a shell-style `\` continuation splits the key over two lines, so only
a multi-line match (`sed -z`) finds and removes it. Archives are evidence: you
list them, you do not edit them. A similar `pk_live_` value belonged to a
partner and a `pk_test_` key is harmless, so each hit has to be read, not just
replaced.

## Common mistakes
- Replacing every `pk_live_[A-Za-z0-9]*`: that destroys the partner's key too.
- Redacting the first half of the split key and leaving the rest behind.
- Forgetting that revoking the key is the real fix; redaction only stops new copies.

## Next step
`git log -p -S'pk_live_'` finds secrets in repository history, and tools like
`gitleaks` automate this search. Always rotate a leaked key first.
