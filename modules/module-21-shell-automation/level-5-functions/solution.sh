#!/bin/bash
# Print the result instead of returning it, validate the input, keep every
# variable local.
cat > lib/units.sh <<'SCRIPT'
# lib/units.sh - size helpers shared by the upload scripts. Source it:
#   source lib/units.sh
#
# to_bytes SIZE   prints SIZE in bytes (K, M, G, T = powers of 1024);
#                 bad input: prints nothing, returns 1.
to_bytes() {
  local number=${1%[KMGT]}
  local unit=${1#"$number"}
  local mult
  case $number in
    ''|*[!0-9]*) return 1 ;;
  esac
  case $unit in
    '') mult=1 ;;
    K) mult=1024 ;;
    M) mult=$((1024 ** 2)) ;;
    G) mult=$((1024 ** 3)) ;;
    T) mult=$((1024 ** 4)) ;;
  esac
  echo $((number * mult))
}
SCRIPT
./check_upload.sh 64K uploads/*
