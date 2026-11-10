#!/bin/bash
# $1 = sandbox path
SANDBOX="$1"
cd "$SANDBOX" || exit 1

mkdir -p build/obj "build/page cache" jobs/2024/q1 jobs/2024/q2 \
         home/alice/.cache/editor templates reports

# Leftovers that must go (12 files)
for f in build/obj/main.o.tmp build/obj/util.o.tmp build/obj/net.o.tmp \
         "build/page cache/page 1.tmp" "build/page cache/page 2.tmp" \
         jobs/2024/q1/job-0107.tmp jobs/2024/q1/job-0213.tmp jobs/2024/q2/job-0402.tmp \
         jobs/2024/q2/job-0519.tmp home/alice/.cache/editor/.swap.tmp \
         home/alice/.session.tmp upload-chunk.tmp; do
  printf 'partial data %s\n' "$f" > "$f"
done

# Files that must survive
printf 'int main(void) { return 0; }\n' > build/obj/main.o
printf '<html>cached page</html>\n' > "build/page cache/index.html"
printf 'Dear {{name}}, your invoice is attached.\n' > templates/invoice.tmpl
printf 'Hello {{name}}!\n' > templates/welcome.tmpl
printf 'job,status\n0107,failed\n0213,failed\n' > jobs/2024/q1/summary.csv
printf 'q2 jobs are archived monthly\n' > jobs/2024/q2/README
printf 'Remember: .tmp files are safe to delete.\n' > reports/notes.tmp.txt
printf 'set number\n' > home/alice/.cache/editor/settings
