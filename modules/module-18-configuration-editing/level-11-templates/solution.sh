#!/bin/bash
# Read each CSV row and substitute with bash's own ${var//pattern/"value"}: with the
# replacement quoted, characters such as / & | \ stay literal.
mkdir -p out
tmpl=$(cat app.conf.tmpl)
tail -n +2 envs.csv | while IFS=, read -r env url pass reps; do
  t=${tmpl//'{{ENV}}'/"$env"}
  t=${t//'{{DB_URL}}'/"$url"}
  t=${t//'{{DB_PASSWORD}}'/"$pass"}
  t=${t//'{{REPLICAS}}'/"$reps"}
  printf '%s\n' "$t" > "out/$env.conf"
done
ls out
cat out/dr.conf
