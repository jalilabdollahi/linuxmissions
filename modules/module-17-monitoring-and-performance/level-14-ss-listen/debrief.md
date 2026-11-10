# Up, But Not Answering

## Why it works
For a socket in state LISTEN, `ss` reuses its two queue columns: Recv-Q is the
number of connections the kernel has completed but the program has not yet
`accept()`ed, and Send-Q is the backlog, the size the program asked for in
`listen()`. When Recv-Q goes past Send-Q the queue is full and new clients are
dropped or left waiting, which they experience as a timeout, even though the
process is alive and the port is open.

## Common mistakes
- Reading Send-Q as "bytes waiting to be sent", which is true only for connected sockets.
- Picking the listener with the smallest backlog: one of them has a backlog of 5 and is perfectly healthy.
- Picking any non-zero Recv-Q: a short queue under the backlog is just a busy server.

## Next step
`ss -ltnp` names the owning process, `ss -tn state established` shows the
clients, and `nstat -az TcpExtListenOverflows` counts how often the queue
overflowed since boot.
