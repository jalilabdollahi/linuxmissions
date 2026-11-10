#!/bin/bash
# Reference solution: declare locals first, assign with $( ) || return,
# strip the CR, check the function's status at the call site.
cat > make_tag.sh <<'SCRIPT'
#!/bin/bash
# make_tag.sh - write the release tag (app-<version>-<sha>-<date>) to release.tag
# The release job runs it in the checkout as:  PATH="$PWD/bin:$PATH" ./make_tag.sh

make_tag() {
  local version sha day
  version=$(< VERSION) || return 1
  version=${version%$'\r'}
  if [ -z "$version" ]; then
    echo "make_tag: VERSION is empty" >&2
    return 1
  fi
  sha=$(git rev-parse --short HEAD) || return 1
  day=${TAG_DATE:-$(date +%Y%m%d)}
  echo "app-$version-$sha-$day"
}

tag=$(make_tag) || { echo "make_tag: could not build the tag, release.tag not written" >&2; exit 1; }
echo "$tag" > release.tag
echo "release tag: $tag"
SCRIPT
PATH="$PWD/bin:$PATH" ./make_tag.sh
