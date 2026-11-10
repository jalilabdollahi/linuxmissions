#!/bin/bash
# Reference solution: write run_all.sh with a heredoc and run it once.
cat > run_all.sh <<'EOF'
#!/bin/bash
# run_all.sh - start the three maintenance tasks in parallel,
# wait for all of them, exit 1 if any failed.
pids=()
for task in ./task-a.sh ./task-b.sh ./task-c.sh; do
  "$task" &
  pids+=("$!")
done

failed=0
for pid in "${pids[@]}"; do
  wait "$pid" || failed=1
done
exit "$failed"
EOF
bash run_all.sh
echo "run_all.sh exit status: $?"
