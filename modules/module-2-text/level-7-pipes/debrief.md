# Pipeline Master

## What you practiced
Pipes (`|`) connect commands so the output of one becomes the input of the next.
This level used a 5-stage pipeline: `grep | awk | sort | uniq -c | sort -rn`

## The power of pipes
Each tool does one thing well. Composing them handles complex transformations without writing a script.

## Commands to remember
```bash
# Classic log analysis pipeline
grep "POST" access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

# tee: write to file AND continue pipeline
cat big.log | tee backup.log | grep ERROR | wc -l

# xargs: use pipeline output as arguments
find . -name "*.log" | xargs wc -l

# process substitution (bash)
diff <(sort file1) <(sort file2)
```
