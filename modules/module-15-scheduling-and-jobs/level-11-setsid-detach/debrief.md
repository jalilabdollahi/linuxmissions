# Cut the Cord

## Why it works
Every process is in a **session**, and a session can own one controlling terminal.
Hangups (SIGHUP when the terminal closes) and keyboard signals (Ctrl-C, Ctrl-\) are
delivered through that terminal. `setsid` makes the program the leader of a brand-new
session that has no terminal at all. Nothing typed into or closed in your shell can reach
it. With stdin from `/dev/null` and output appended to a log, it never touches a terminal
again.

## Common mistakes
- `nohup ./consumer.sh &` ignores SIGHUP, but the process stays in your shell's session with
  your terminal, and `kill %1` or a stray signal to the job still reaches it.
- `( ./consumer.sh & )` changes the parent (it becomes a child of init), not the session
  or the terminal.
- `disown` only removes the job from bash's job table, so bash won't send it SIGHUP on exit.
  The process itself is unchanged, and nothing outside bash can even see that it happened.

## Next step
Daemons detach this way (fork, setsid, redirect the standard fds). On a systemd box, the
better answer for a long-lived consumer is a service unit (`Restart=on-failure`), which
also restarts it when it crashes. `ps -eo pid,pgid,sid,tty,cmd` shows sessions for all processes.
