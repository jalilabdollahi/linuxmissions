# Logfmt To CSV

## Why it works
In logfmt the position of a value means nothing, only its key does. The loop
over `1..NF` looks at every field, `index` + `substr` split it at the first
`=`, and `k == "dur"` compares the whole key, so `db_dur=` and
`upstream_svc=` are ignored. awk turns a string into a number by reading its
leading digits, so `"850ms" + 0` is 850 and `"1.2s" * 1000` is 1200. Resetting
`ts`, `svc` and `dur` on each line stops values leaking from the line before.

## Common mistakes
- Matching keys with a regex like `/dur=/` or `sub(/.*svc=/, "")`: that also
  finds `db_dur=` and `upstream_svc=`.
- Truncating instead of rounding: in binary floating point 2.344 * 1000 can
  be 2343.9999999999995, and `%d` or `int()` turns that into 2343.
- Treating every number as ms: `730us` is 0.73 ms, and `0.5s` is exactly the
  limit, not above it.

## Learn next
The message field is quoted and contains blanks, so splitting on blanks cuts
it apart; we never needed it here. When you do, GNU awk's `FPAT` defines
fields by their content:
`gawk -v FPAT='[^ =]+=("[^"]*"|[^ ]*)' ...` keeps `msg="request done"` in one
field. For logs you parse often, `jq` on JSON logs or a dedicated tool (such
as `hl` or `lnav`) saves this work.
