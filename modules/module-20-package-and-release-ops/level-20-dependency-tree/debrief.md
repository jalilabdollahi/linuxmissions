# Drop libold1: Who Goes With It?

## Why it works
`apt-get -s remove` runs apt's own resolver without touching the system, so its answer already follows the
dependency rules: a package goes only if one of its hard dependencies (`Depends`, `Pre-Depends`) can no
longer be satisfied, and that is checked again for the packages that were just marked for removal. That is
why dependents of dependents appear, and why a package that depends on `libold1 | libnew1` or on a virtual
package that `libnew1` also provides stays. `apt-cache rdepends` only lists who *mentions* the package, in
any field and for uninstalled packages too.

## Common mistakes
- Copying the `rdepends` list: it includes Recommends, Suggests, alternatives and packages that are not installed.
- Stopping after one level: removing a library takes its dependents and *their* dependents.
- Running the real `apt-get remove`: the dependents are gone and the question can no longer be answered.

## Next step
`apt-get -s autoremove` shows what becomes unneeded afterwards, `apt-cache rdepends --installed --recurse PKG` is a
quick over-approximation, and `apt-mark showmanual` tells you which of the removed packages somebody asked for.
