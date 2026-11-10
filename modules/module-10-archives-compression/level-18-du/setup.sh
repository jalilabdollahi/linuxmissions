#!/bin/bash
# $1 = sandbox path
# projects/ with cache dirs of random sizes. Sizes are either clearly below
# 5 MiB (<= 3.5 MiB) or clearly above (>= 6 MiB), so block-size differences
# between filesystems never move a dir across the line. Several dirs flip a
# coin, so the answer changes from one setup to the next.
SANDBOX="$1"
cd "$SANDBOX" || exit 1

fill() {  # fill DIR KiB NAME...  -> spread KiB of random data over the named files
  local dir=$1 kib=$2; shift 2
  local n=$# f
  mkdir -p "$dir"
  for f in "$@"; do
    mkdir -p "$(dirname "$dir/$f")"
    head -c $(( kib * 1024 / n )) /dev/urandom > "$dir/$f"
  done
}
small() { echo $(( 1024 + RANDOM % 2560 )); }   # 1 - 3.5 MiB
big()   { echo $(( 6144 + RANDOM % 2048 )); }   # 6 - 8 MiB
coin()  { if [ $((RANDOM % 2)) = 0 ]; then small; else big; fi; }

P=projects

# webshop: JS app. node_modules holds a nested node_modules and a build dir of its own.
fill $P/webshop/src 60 app.js cart.js checkout.js styles.css
printf '{ "name": "webshop", "version": "3.1.0" }\n' > $P/webshop/package.json
fill $P/webshop/node_modules "$(big)" react/index.js react-dom/cjs/react-dom.production.min.js lodash/lodash.js typescript/lib/typescript.js
fill $P/webshop/node_modules/esbuild/node_modules "$(big)" @esbuild/linux-x64/bin/esbuild esbuild-wasm/esbuild.wasm
fill $P/webshop/node_modules/sharp/build "$(small)" Release/sharp-linux-x64.node Release/obj/sharp.o
fill $P/webshop/.cache "$(coin)" parcel/a1f3.cache parcel/b77e.cache parcel/c09d.cache
fill $P/webshop/build "$(coin)" static/js/main.js static/js/vendor.js static/media/hero.jpg
fill $P/webshop/assets/videos 7168 intro.mp4 tutorial.mp4    # big, but not a cache

# billing-api: Rust. target/ has a nested build/ dir.
fill $P/billing-api/src 40 main.rs invoice.rs db.rs
printf '[package]\nname = "billing-api"\n' > $P/billing-api/Cargo.toml
fill $P/billing-api/target "$(big)" debug/billing-api debug/deps/libtokio.rlib release/billing-api
fill $P/billing-api/target/debug/build "$(big)" ring-4c1f/out/libring.a openssl-sys-9e2b/out/libssl.a

# ml-notebooks: a hidden model cache and a big data dir that is not a cache
fill $P/ml-notebooks/.cache "$(big)" huggingface/hub/model.safetensors pip/http/wheel.whl
fill $P/ml-notebooks/data 7168 raw/2026-10.parquet raw/2026-11.parquet
fill $P/ml-notebooks/notebooks 30 explore.ipynb train.ipynb

# legacy-site: small caches only
fill $P/legacy-site/build "$(small)" index.html bundle.js
fill $P/legacy-site/node_modules "$(small)" jquery/dist/jquery.js bootstrap/dist/js/bootstrap.js
fill $P/legacy-site/public 200 logo.png favicon.ico

# mobile-app: Gradle-style build dir (coin), and a file named "target" (not a dir)
fill $P/mobile-app/build "$(coin)" outputs/apk/app-debug.apk intermediates/dex/classes.dex
fill $P/mobile-app/app/.cache "$(coin)" gradle/transforms.bin
fill $P/mobile-app/app/src 50 MainActivity.kt
printf 'deploy target: play-store-internal\n' > $P/mobile-app/target

cat > ARCHIVE-PLAN.txt <<'EOF'
Before projects/ goes to cold storage, find what bloats it. Caches can be
rebuilt, so we'll exclude every cache dir (node_modules, .cache, target,
build) that is larger than 5 MiB. A cache dir inside another cache dir is
already part of its parent: list only the outermost one.
EOF
