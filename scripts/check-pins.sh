#!/usr/bin/env bash
# The component installs one gocov CLI release: the `version` input's
# default in templates/upload.yml. That default is the pin, and it is
# authoritative; this fails CI when anything else in the repo (the README
# table, a workflow) names a different CLI release.
#
# Deliberately not checked: whether that default is the newest gocov
# release. Between a CLI release and the bump PR that follows it the pin
# is legitimately one behind; scripts/verify-release.sh in the gocov repo
# holds the wrappers level with the CLI, after the release exists.
set -euo pipefail

cd "$(dirname "$0")/.."

default=$(sed -n 's/^ *default: *\(v[0-9]*\.[0-9]*\.[0-9]*\) *$/\1/p' templates/upload.yml)
if [ -z "$default" ]; then
  echo "check-pins: no 'default: vX.Y.Z' found in templates/upload.yml." >&2
  exit 1
fi
if [ "$(echo "$default" | wc -l | tr -d ' ')" -ne 1 ]; then
  echo "check-pins: templates/upload.yml has more than one version-shaped default:" >&2
  printf '%s\n' "$default" | sed 's/^/  /' >&2
  exit 1
fi

pins=$(git grep -InEo \
  -e 'releases/download/v[0-9]+\.[0-9]+\.[0-9]+' \
  -e '`v[0-9]+\.[0-9]+\.[0-9]+`' \
  -e 'version: *v[0-9]+\.[0-9]+\.[0-9]+' \
  -- ':!scripts/check-pins.sh' ':!CHANGELOG.md' || true)

bad=$(echo "$pins" | grep -F -v "$default" || true)
if [ -n "$bad" ]; then
  echo "check-pins: these pin a gocov CLI release other than the template's default ($default):" >&2
  printf '%s\n' "$bad" | sed 's/^/  /' >&2
  exit 1
fi
# The newest CHANGELOG.md entry is the release the next merge tags, and
# names the CLI it installs in the phrase every entry uses — "Install
# gocov CLI v0.26.1 (was v0.26.0)". Only the first "gocov CLI vX" is
# matched, not the version it replaces. An entry that changes nothing
# about the CLI need not name one; one that contradicts the template
# fails. The same check runs in gocov-action and upload-pipe.
version=$(sed -n 's/^## \([0-9][0-9.]*\) *$/\1/p' CHANGELOG.md | head -1)
if [ -z "$version" ]; then
  echo "check-pins: no '## X.Y.Z' heading in CHANGELOG.md." >&2
  exit 1
fi
claimed=$(awk '/^## /{n++} n==1' CHANGELOG.md | sed -n 's/.*gocov CLI \(v[0-9][0-9.]*[0-9]\).*/\1/p' | head -1)
if [ -n "$claimed" ] && [ "$claimed" != "$default" ]; then
  echo "check-pins: CHANGELOG.md's $version entry says it installs $claimed, but templates/upload.yml pins $default." >&2
  exit 1
fi

echo "check-pins: CLI pinned at $default in templates/upload.yml${claimed:+ (as CHANGELOG.md $version says)}; $(echo "$pins" | grep -c . | tr -d ' ') other pin(s) agree"
