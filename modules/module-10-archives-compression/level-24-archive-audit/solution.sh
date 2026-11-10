#!/bin/bash
# Audit every archive by content, then extract only the verified and safe ones.
cat > audit.sh <<'EOF'
cd "$SANDBOX"
echo "name,real_type,members,checksum_ok,unsafe" > audit.csv
for f in delivery/*; do
  n=${f#delivery/}
  [ "$n" = SHA256SUMS ] && continue
  case "$(file -b "$f")" in
    Zip*)   t=zip ;;
    gzip*)  t=tar.gz ;;
    bzip2*) t=tar.bz2 ;;
    XZ*)    t=tar.xz ;;
    *tar*)  t=tar ;;
    *)      echo "unknown type: $f"; continue ;;
  esac
  if [ "$t" = zip ]; then list=$(unzip -Z1 "$f"); else list=$(tar -tf "$f" 2>/dev/null); fi
  members=$(printf '%s\n' "$list" | grep -c .)
  if grep -qxF "$(sha256sum < "$f" | cut -d' ' -f1)  $n" delivery/SHA256SUMS; then ok=yes; else ok=no; fi
  if printf '%s\n' "$list" | grep -Eq '^/|(^|/)\.\.(/|$)'; then bad=yes; else bad=no; fi
  echo "$n,$t,$members,$ok,$bad" >> audit.csv
  if [ "$ok" = yes ] && [ "$bad" = no ]; then
    mkdir -p "accepted/${n%%.*}"
    if [ "$t" = zip ]; then unzip -q "$f" -d "accepted/${n%%.*}"; else tar -xf "$f" -C "accepted/${n%%.*}"; fi
  fi
done
EOF
bash audit.sh
cat audit.csv
ls accepted
