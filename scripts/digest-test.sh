#!/usr/bin/env bash
# Tests scripts/digest.sh: a sealed folder passes, and every change to it fails.
#   scripts/digest-test.sh
set -euo pipefail
digest="$(cd "$(dirname "$0")" && pwd)/digest.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

pass() { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }

# sealed NAME: makes a folder with two files, one in a subfolder, seals it, and prints its digest.
sealed() {
  mkdir -p "$work/$1/sub"
  printf 'app\n' > "$work/$1/Fixit.app.tar"
  printf 'dmg\n' > "$work/$1/sub/Fixit.dmg"
  "$digest" write "$work/$1"
}

expect_pass() { if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }
expect_fail() { if "$@" >/dev/null 2>&1; then fail "$label"; else pass "$label"; fi; }

d="$(sealed good)"
label="a sealed folder passes"
expect_pass "$digest" verify "$work/good" "$d"

d="$(sealed wrong-digest)"
label="a wrong digest fails"
expect_fail "$digest" verify "$work/wrong-digest" "$(printf '%064d' 0)"

d="$(sealed malformed-digest)"
label="a digest that is not a sha256 fails"
expect_fail "$digest" verify "$work/malformed-digest" "${d:0:63}"

d="$(sealed changed)"
printf 'swapped\n' > "$work/changed/sub/Fixit.dmg"
label="a changed file fails"
expect_fail "$digest" verify "$work/changed" "$d"

d="$(sealed extra)"
printf 'extra\n' > "$work/extra/extra.zip"
label="an extra file fails"
expect_fail "$digest" verify "$work/extra" "$d"

d="$(sealed extra-link)"
ln -s Fixit.app.tar "$work/extra-link/link.tar"
label="an extra symlink fails"
expect_fail "$digest" verify "$work/extra-link" "$d"

d="$(sealed missing)"
rm "$work/missing/sub/Fixit.dmg"
label="a missing file fails"
expect_fail "$digest" verify "$work/missing" "$d"

d="$(sealed rewritten)"
printf 'swapped\n' > "$work/rewritten/Fixit.app.tar"
"$digest" write "$work/rewritten" >/dev/null
label="a folder sealed again after a change fails against the first digest"
expect_fail "$digest" verify "$work/rewritten" "$d"

mkdir "$work/empty"
label="sealing an empty folder fails"
expect_fail "$digest" write "$work/empty"
label="an empty folder fails"
expect_fail "$digest" verify "$work/empty" "$d"

if [ "$failures" -ne 0 ]; then
  echo "$failures digest.sh test(s) failed" >&2
  exit 1
fi
echo "all digest.sh tests passed"
