#!/bin/bash
# Replace the TODO with a getopts loop plus the shift.
python3 - <<'PY'
import re
p = "rotate.sh"
s = open(p).read()
parse = '''while getopts ':n:d:v' opt; do
  case $opt in
    n) count=$OPTARG ;;
    d) dir=$OPTARG ;;
    v) verbose=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[ -n "$dir" ] || usage
'''
s = re.sub(r"# TODO: parse.*?patterns\.\n", parse, s, flags=re.S)
open(p, "w").write(s)
PY
./rotate.sh -vn3 -d logs
ls logs
