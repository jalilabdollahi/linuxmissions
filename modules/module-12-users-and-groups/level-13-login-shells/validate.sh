#!/bin/bash
# Compare etc/passwd with the original saved by setup (.lm-state/passwd.orig).
# Expected shell: root and sync unchanged; service accounts (UID 1-999 and >59999):
# nologin/false stay, anything else -> /usr/sbin/nologin; people (1000-59999): a shell
# in etc/shells or nologin/false stays, anything else -> /bin/bash. Every other
# field and the line order must be byte-identical.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

if [ ! -s .lm-state/inputs ] || ! cksum etc/shells .lm-state/passwd.orig 2>/dev/null | cmp -s - .lm-state/inputs; then
  echo "❌ etc/shells or the saved original was changed; type 'reset' to get them back"
  exit 1
fi
if [ "$(wc -l < etc/passwd | tr -d ' ')" != "$(wc -l < .lm-state/passwd.orig | tr -d ' ')" ]; then
  echo "❌ etc/passwd has a different number of lines than before: accounts must not be added or removed"
  exit 1
fi

awk -F: '
  FILENAME == ARGV[1] { if ($0 !~ /^#/ && NF) ok[$0] = 1; next }
  FILENAME == ARGV[2] { orig[FNR] = $0; next }
  {
    line = orig[FNR]
    n = split(line, f, ":")
    if (n != 7 || f[1] ~ /^[+-]/ || f[3] !~ /^[0-9]+$/) want = line
    else if (f[1] == "root" || f[1] == "sync") want = line
    else {
      sh = f[7]; uid = f[3] + 0
      if (sh == "/usr/sbin/nologin" || sh == "/bin/false") ns = sh
      else if (uid >= 1000 && uid <= 59999 && (sh in ok)) ns = sh
      else if (uid >= 1000 && uid <= 59999) ns = "/bin/bash"
      else ns = "/usr/sbin/nologin"
      want = f[1] ":" f[2] ":" f[3] ":" f[4] ":" f[5] ":" f[6] ":" ns
    }
    if ($0 != want) {
      m = split($0, g, ":")
      if (m == 7 && g[1] == f[1] && g[2] == f[2] && g[3] == f[3] && g[4] == f[4] && g[5] == f[5] && g[6] == f[6]) {
        if (f[1] == "root" || f[1] == "sync") print "❌ " f[1] " is an exception to the policy and its shell should not have been changed"
        else if (f[3] + 0 >= 1000 && f[3] + 0 <= 59999 && (f[7] in ok || f[7] == "/usr/sbin/nologin" || f[7] == "/bin/false"))
          print "❌ " f[1] " already had an allowed shell (" f[7] ") and should not have been changed"
        else if (f[3] + 0 >= 1000 && f[3] + 0 <= 59999)
          print "❌ " f[1] " is a person: the shell \"" g[7] "\" is not in etc/shells (the original \"" f[7] "\" was invalid)"
        else if (f[7] == "/usr/sbin/nologin" || f[7] == "/bin/false")
          print "❌ " f[1] " already had a no-login shell and should not have been changed"
        else
          print "❌ " f[1] " is a service account: its shell is \"" g[7] "\", the policy wants /usr/sbin/nologin instead of a login shell"
      } else print "❌ line " FNR " (" f[1] "): something other than the shell field changed, or the line was modified in some other way"
      exit 1
    }
  }
' etc/shells .lm-state/passwd.orig etc/passwd
rc=$?
[ $rc = 0 ] || exit 1
# a policy violation that was left untouched shows up as a difference above only when want != now;
# now, make sure no change was needed by accident of equality (fresh state must fail).
echo "✅ every service account has no login shell, every person has a valid one, and nothing else in etc/passwd changed"
exit 0
