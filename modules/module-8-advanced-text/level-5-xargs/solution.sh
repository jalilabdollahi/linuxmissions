#!/bin/bash
# grep -l lists matching files; --null ends each name with a NUL byte, and
# xargs -0 splits on NUL only, so spaces and apostrophes in names are safe.
grep -rl --null 'NEBULA_KEY' files | xargs -0 -I{} mv {} quarantine/
ls quarantine
