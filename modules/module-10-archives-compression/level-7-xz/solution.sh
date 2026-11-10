#!/bin/bash
mkdir -p archive
for m in 2026-05 2026-06 2026-07 2026-08 2026-09 2026-10; do
  tar -cJf "archive/$m.tar.xz" logs/app-$m-*.log &&
    xz -t "archive/$m.tar.xz" &&
    tar -tJf "archive/$m.tar.xz" | wc -l &&
    rm logs/app-$m-*.log
done
ls -l archive logs | head
