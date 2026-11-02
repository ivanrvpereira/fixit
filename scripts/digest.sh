#!/usr/bin/env bash
# Seals the files that one release job hands to the next, and checks them in the next job.
#   digest.sh write DIR          writes DIR/SHA256SUMS for every file in DIR and prints its sha256 (the digest).
#   digest.sh verify DIR DIGEST  fails unless DIR/SHA256SUMS has that sha256, every file matches it, and DIR
#                                holds no other files.
# The digest travels as a job output, not in the artifact, so a file swapped in the artifact store fails.
set -euo pipefail
usage="usage: digest.sh write DIR | digest.sh verify DIR DIGEST"
cmd="${1:?$usage}"
dir="${2:?$usage}"
cd "$dir"

# sha256sum on Linux, shasum on macOS: both print "HASH  FILE" and take -c --strict --quiet.
if command -v sha256sum >/dev/null; then sha() { sha256sum "$@"; }; else sha() { shasum -a 256 "$@"; }; fi

# Everything that is not a folder counts, so an added symlink is an extra file too.
listed() { find . ! -type d ! -name SHA256SUMS | sed 's|^\./||' | LC_ALL=C sort; }

case "$cmd" in
  write)
    rm -f SHA256SUMS
    # The list goes outside DIR first, so that it does not list itself.
    sums="$(mktemp)"
    listed | while IFS= read -r f; do sha -- "$f"; done > "$sums"
    test -s "$sums" || { rm -f "$sums"; echo "digest.sh: no files in $dir" >&2; exit 1; }
    mv "$sums" SHA256SUMS
    chmod 644 SHA256SUMS
    sha SHA256SUMS | cut -d' ' -f1
    ;;
  verify)
    want="${3:?$usage}"
    [[ "$want" =~ ^[0-9a-f]{64}$ ]] || { echo "digest.sh: not a sha256 digest: '$want'" >&2; exit 1; }
    test -f SHA256SUMS || { echo "digest.sh: no SHA256SUMS in $dir" >&2; exit 1; }
    got="$(sha SHA256SUMS | cut -d' ' -f1)"
    test "$got" = "$want" || { echo "digest.sh: SHA256SUMS in $dir does not match the digest of the job that made it" >&2; exit 1; }
    sha -c --strict --quiet SHA256SUMS
    diff <(listed) <(sed 's/^[0-9a-f]*  //' SHA256SUMS | LC_ALL=C sort) >/dev/null \
      || { echo "digest.sh: $dir holds files that SHA256SUMS does not list" >&2; exit 1; }
    echo "verified $dir"
    ;;
  *)
    echo "$usage" >&2
    exit 2
    ;;
esac
