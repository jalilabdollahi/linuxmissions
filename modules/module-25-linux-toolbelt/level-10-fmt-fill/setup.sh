#!/bin/bash
# NOTES.txt: a title, intro/closing paragraphs and two bullet lists. Every
# sentence is on its own line; some lines are over 72 characters. The lists are
# indented by 2 spaces; bullets ("- " first line) are separated by blank lines.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

awk -v seed="$RANDOM$$" '
function pick(a, n) { return a[1 + int(rand() * n)] }
function sentence(   s) {
  s = pick(subj, ns) " " pick(verb, nv) " " pick(obj, no)
  if (rand() < 0.5) s = s " " pick(tail, nt)
  return s "."
}
function para(k,   i) { for (i = 0; i < k; i++) print sentence() }
function bullet(k,   i) {
  print "  - " pick(head, nh) "."
  for (i = 1; i < k; i++) print "  " sentence()
}
BEGIN {
  srand(seed)
  ns = split("The importer|The scheduler|Login|The export dialog|The search index|Backups|The mobile app|The API|Error messages|The audit log", subj, "|")
  nv = split("now starts|no longer blocks|finally handles|is much faster at|was rewritten to cope with|now reports progress while|can resume after|stays responsive when", verb, "|")
  no = split("large files|expired sessions|network timeouts|files with unusual names|thousands of concurrent users|a full disk|duplicate entries|time zone changes", obj, "|")
  nt = split("without asking for a restart|and keeps a copy of the previous state|on every supported platform|even when the server is under heavy load", tail, "|")
  nh = split("Faster imports|Safer upgrades|Clearer errors|Smaller downloads|Better search|Offline mode|Fewer prompts|Stricter validation|New export formats", head, "|")
  printf "Release %d.%d notes\n\n", 2 + int(rand() * 6), int(rand() * 10)
  para(4 + int(rand() * 3)); print ""
  print "Highlights"; print ""
  nb = 3 + int(rand() * 2); for (b = 0; b < nb; b++) { if (b) print ""; bullet(2 + int(rand() * 3)) }
  print ""
  para(3 + int(rand() * 3)); print ""
  print "Known issues"; print ""
  nb = 2 + int(rand() * 2); for (b = 0; b < nb; b++) { if (b) print ""; bullet(2 + int(rand() * 2)) }
  print ""
  para(3)
}' > NOTES.txt
cp NOTES.txt .lm-state/notes.orig
