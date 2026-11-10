# Quarter From Three Months

## Why it works
`head -n 1` takes the header once. In awk, `NR` counts lines across all input
files but `FNR` restarts at 1 for every file, so `FNR > 1` drops each file's
header. awk reads the last line of feb.csv even without its newline and, like
every record it prints, ends it with one; `cat` and `tail` copy the bytes as
they are, so February's last invoice and March's first would share a line.
Naming the files in the command (`jan.csv feb.csv mar.csv`) fixes the order;
a glob sorts alphabetically: feb, jan, mar.

## Common mistakes
- `cat *.csv`: three headers, alphabetical order, and once q1.csv exists it
  matches the glob too.
- `tail -n +2 jan.csv feb.csv mar.csv` with several files prints `==> file <==`
  banners; add `-q`, and the missing newline still glues two rows.
- Fixing the input with `echo >> feb.csv`: it works, but changes a file you
  were asked to leave alone.

## Learn next
`awk 'NR == 1 || FNR > 1' jan.csv feb.csv mar.csv` does it in one command.
`tail -c 1 FILE | od -c` tells you whether a file ends in a newline, and
`sed -e '$a\'` (GNU sed) adds one only where it is missing.
