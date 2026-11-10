#!/bin/bash
# Rewrite each link that points into the old home as a relative link. -s keeps
# realpath from following the (still dangling) links on the way; -n makes ln
# replace a link to a directory instead of creating a link inside it.
old=$(readlink app/current | sed 's#/releases/.*##')
find app -type l | while IFS= read -r l; do
  t=$(readlink "$l")
  case "$t" in
    "$old"/*)
      new="$PWD/app/${t#"$old"/}"
      ln -sfn "$(realpath -sm --relative-to="$(dirname "$l")" "$new")" "$l"
      ;;
  esac
done
find app -type l -exec ls -l {} +
