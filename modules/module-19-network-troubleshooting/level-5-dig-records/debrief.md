# Where Does the Mail Go?

## Why it works
A sending mail server sorts the MX records by preference and tries the
*lowest* number first; the others are backups. dig returns them in whatever
order the server sends, and a plain `sort` compares text, so "20" comes before
"5": `sort -n` compares numbers. Asking for the A record of the primary MX
returns the whole CNAME chain (mx → mailrelay → edge), and the last line of
`+short` is the address.

The chain is also a likely reason for the bounces: an MX target must be a
name with A/AAAA records, not an alias (RFC 2181 section 10.3). Many mail
servers follow the CNAME anyway, some refuse.

## Common mistakes
- Taking the first MX dig prints, or the highest number.
- Writing the CNAME target as MX_HOST: the MX record names the host, the CNAMEs are its aliases.
- Forgetting `-p`: dig then asks port 53, where no server is listening.

## Learn next
`dig +trace NAME` follows the delegation from the root servers down (needs
internet), and `dig NAME MX +noall +answer +additional` shows the addresses the
server sends along with the MX answer, when it has them.
