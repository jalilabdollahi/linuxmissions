#!/bin/bash
# A Makefile whose recipe lines were converted to 8 spaces. Also present:
# a "\"-continued variable with 8-space continuation lines, 8-space indented
# comments outside recipes, a .PHONY line, and a recipe that continues over
# several lines with a backslash. Names are random per setup.
SANDBOX="$1"
cd "$SANDBOX" || exit 1
mkdir -p .lm-state

pick() { local a=("$@"); echo "${a[RANDOM % ${#a[@]}]}"; }
prog=$(pick tracker relay ledger scanner packer)
c1=$(pick main util parse net)
c2=$(pick io cache queue log)
c3=$(pick config timer crypto alloc)
opt=$(pick -O1 -O2 -O3 -Os)
P='        '   # 8 spaces
cat > Makefile <<MK
# Build file for $prog
CC      = gcc
CFLAGS  = $opt -Wall -Wextra \\
$P-DVERSION=\\"$((1 + RANDOM % 4)).$((RANDOM % 10))\\" \\
$P-DNDEBUG
SRCS    = $c1.c $c2.c \\
$P$c3.c
OBJS    = \$(SRCS:.c=.o)

.PHONY: all clean test install

all: $prog

$prog: \$(OBJS)
${P}@echo "linking \$@"
${P}\$(CC) \$(CFLAGS) -o \$@ \$(OBJS)

%.o: %.c
${P}\$(CC) \$(CFLAGS) -c \$< -o \$@

$P# the targets below are for developers only
$P# (CI runs 'make test' directly)
test: $prog
${P}./$prog --selftest && \\
${P}echo "selftest passed" || \\
${P}{ echo "selftest FAILED"; exit 1; }

install: $prog
${P}install -d \$(DESTDIR)/usr/local/bin
${P}install -m 755 $prog \$(DESTDIR)/usr/local/bin/

$P# remove build products
clean:
${P}rm -f \$(OBJS) $prog
MK
cp Makefile Makefile.orig
cp Makefile .lm-state/Makefile.orig
