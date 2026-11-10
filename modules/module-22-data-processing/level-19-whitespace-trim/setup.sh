#!/bin/bash
# Directory Export: a TSV from the HR system with padded fields, runs of
# spaces, non-breaking spaces (U+00A0) at the ends of and inside fields, CRLF
# on the lines that were edited by hand, accented names, and users exported
# twice. Random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function pad(s,   r) {
  r = rand()
  if (r < 0.55) return s
  if (r < 0.70) return s " "
  if (r < 0.78) return "  " s
  if (r < 0.88) return s NB
  if (r < 0.94) return NB s "  "
  return " " s NB " "
}
function inner(s) { if (rand() < 0.15) sub(/ /, (rand() < 0.5 ? "   " : NB), s); return s }
BEGIN {
  srand(seed)
  NB = "\302\240"
  nf = split("Anna|José|Zoë|Bjørn|Chen|Dana|Elif|Femi|Greta|Hugo|Inês|Jonas|Kofi|Lara|Mats|Nina|Omar|Petra|Søren|Tara", fn, "|")
  nl = split("Berg|Okafor|Wei|Kovač|Yılmaz|Adeyemi|Lind|Marchetti|Duarte|Weber|Mensah|Novak|Holm|Strand|Falk|Müller|Kaya|Costa|Lund|Vogel", ln, "|")
  nd = split("Engineering|Finance|Customer Success|Sales|People Ops|Legal", dep, "|")
  nt = split("Software Engineer|Senior Software Engineer|Account Executive|Payroll Specialist|Support Lead|Data Analyst|Office Manager|Counsel|", ttl, "|")
  printf "username\temail\tdisplay_name\tdepartment\ttitle \r\n"
  n = 140 + int(rand() * 40)
  for (i = 1; i <= n; i++) {
    do { a = int(rand() * nf) + 1; b = int(rand() * nl) + 1; u = sprintf("u%04d", 1000 + int(rand() * 8999)) } while (u in seen)
    seen[u] = 1; nu++; U[nu] = u; A[nu] = a; B[nu] = b
  }
  for (i = 1; i <= n; i++) {
    # some users come back later in the export (a second, older record)
    k = (i > 20 && rand() < 0.07) ? int(rand() * (i - 1)) + 1 : i
    u = U[k]; a = fn[A[k]]; b = ln[B[k]]
    name = a " " b
    if (rand() < 0.3 && k == i) name = a " " substr("ABCDEFGHJKLMNPRST", int(rand() * 17) + 1, 1) ". " b
    mail = sprintf("%s.%s@corp.example", tolower(a), tolower(b))
    title = ttl[int(rand() * nt) + 1]
    eol = (rand() < 0.15) ? "\r\n" : "\n"
    printf "%s\t%s\t%s\t%s\t%s%s", pad(u), pad(mail), pad(inner(name)), pad(inner(dep[int(rand() * nd) + 1])), pad(inner(title)), eol
  }
}' > users.tsv

cksum < users.tsv > .lm-state/users.sum
