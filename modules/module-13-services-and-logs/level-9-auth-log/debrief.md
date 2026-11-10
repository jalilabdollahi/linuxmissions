# Did They Get In?

## Why it works
A brute force that worked leaves a pattern: a run of `Failed password` lines from one IP,
then `Accepted ... for USER from` *the same IP*. awk reads the file in time order, so a
running counter per IP (`fails[ip] += n`) holds exactly "failures so far" at the moment of
each `Accepted` line. Logins that came *before* the failures (the office IP) and logins
after only 4 typos (a colleague) don't trigger it.

Three details of the format matter:
- `Failed password for invalid user admin from ...` has two words more than
  `Failed password for root from ...`, so `$11` is sometimes the IP and sometimes not. Cutting
  around `from` avoids that.
- rsyslog folds repeats on the same connection into
  `message repeated 4 times: [ Failed password ... ]`, which is four attempts in one line.
- The user that matters is the one in the `Accepted` line. Attackers often try root first
  and get in with a weak service account.

## Common mistakes
- `grep -c 'Failed password'` per IP: it undercounts folded repeats and ignores the order.
- Taking every IP that has both failures and a login, without checking which came first.
- Counting `pam_unix(...): authentication failure` lines as well. They are the same attempts
  logged a second time by PAM.

## Next step
Act on it: lock the accounts (`usermod -L`, expire their keys), look for what the sessions
did (`last -i`, `journalctl _COMM=sshd`, `.bash_history`), and stop it next time with
`PasswordAuthentication no` in `sshd_config` and fail2ban or `MaxAuthTries`.
