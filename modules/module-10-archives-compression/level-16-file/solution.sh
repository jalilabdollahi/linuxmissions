#!/bin/bash
# Ask `file` what each chunk really is; look inside gzip with -z to spot tar.gz.
for f in recovered/*; do
  n=$(basename "$f"); n=${n%%.*}
  case "$(file -b "$f")" in
    empty)          t=empty ;;
    gzip*)          if file -bz "$f" | grep -q 'tar archive'; then t=tar.gz; else t=gz; fi ;;
    bzip2*)         t=bz2 ;;
    XZ*)            t=xz ;;
    Zip*)           t=zip ;;
    *tar\ archive*) t=tar ;;
    PNG*)           t=png ;;
    PDF*)           t=pdf ;;
    *text*)         t=txt ;;
    *)              echo "unknown: $f: $(file -b "$f")"; continue ;;
  esac
  mkdir -p "sorted/$t"
  if [ "$t" = empty ]; then mv "$f" "sorted/empty/$n"; else mv "$f" "sorted/$t/$n.$t"; fi
done
ls recovered | wc -l
ls sorted
