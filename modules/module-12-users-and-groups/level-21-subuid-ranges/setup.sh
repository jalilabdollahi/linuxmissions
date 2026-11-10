#!/bin/bash
# build-03: etc/passwd, etc/group, etc/subuid, etc/subgid (shared mock usermod
# can add ranges). Existing ranges are in shuffled order, one has an odd count
# (100000), so "last line + 65536" overlaps; subuid and subgid differ; nina
# already has a subuid range but no subgid one.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
M="$(dirname "$0")/../../../mocks"
mkdir -p bin etc .lm-state
for t in usermod getent id; do cp "$M/accounts/$t" bin/; done

python3 - "$RANDOM$$" <<'PY'
import random, sys
R = random.Random(int(sys.argv[1]))
def block(users, start, counts):
    out, s = [], start
    for u, c in zip(users, counts):
        out.append("%s:%d:%d" % (u, s, c))
        s += c + R.choice([0, 0, 0, 7000])
    return out, s
# subuid: five contiguous-ish ranges starting at 100000, the 4th with count 100000, then nina above them
a_users = ["svc-build", "alice", "carol", "dave", "erin"]
a_counts = [65536, 65536, 65536, 100000, 65536]
sub_u, end_u = block(a_users, 100000, a_counts)
sub_u.append("nina:%d:65536" % (end_u + 4000))
R.shuffle(sub_u)
sub_u.sort(key=lambda l: l.startswith("dave:"))   # the 100000-count range ends up last
# subgid: different layout, odd count on another account
g_users = ["alice", "svc-build", "dave", "erin", "carol"]
g_counts = [65536, 65536, 65536, 65536, 131072]
sub_g, end_g = block(g_users, 100000 + R.choice([0, 65536]), g_counts)
R.shuffle(sub_g)
sub_g.sort(key=lambda l: l.startswith("carol:"))  # the 131072-count range ends up last
open("etc/subuid", "w").write("\n".join(sub_u) + "\n")
open("etc/subgid", "w").write("\n".join(sub_g) + "\n")

people = ["alice", "carol", "dave", "erin", "nina", "omar", "pavel"]
pw = ["root:x:0:0:root:/root:/bin/bash", "svc-build:x:998:998:CI build account:/var/lib/svc-build:/usr/sbin/nologin"]
gr = ["root:x:0:", "svc-build:x:998:"]
for i, p in enumerate(people):
    pw.append("%s:x:%d:%d:%s:/home/%s:/bin/bash" % (p, 1001 + i, 1001 + i, p.title(), p))
    gr.append("%s:x:%d:" % (p, 1001 + i))
open("etc/passwd", "w").write("\n".join(pw) + "\n")
open("etc/group", "w").write("\n".join(gr) + "\n")
PY
cp etc/subuid .lm-state/subuid.orig
cp etc/subgid .lm-state/subgid.orig

cat > TICKET.md <<'LMEND'
# PLAT-771: rootless containers on build-03

omar, pavel and nina are moving their builds to rootless podman. Each of them
needs a block of 65536 subordinate UIDs (etc/subuid) and 65536 subordinate GIDs
(etc/subgid). The ranges must start at 100000 or above and must not overlap
anyone else's range in the same file: overlapping ranges let two users map to
the same IDs and read each other's container files.

nina was set up part of the way last week; do not give her a second range.
Existing lines stay as they are (other teams own them).
LMEND
