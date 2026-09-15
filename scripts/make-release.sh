#!/bin/sh
# Builds the app, zips it as build/Sample-Search-<version>.zip and tags the commit v<version>.
# Then create a GitHub release for that tag and upload the zip (the in-app update check reads it).
set -eu
cd "$(dirname "$0")/.."
VERSION=$(cat VERSION)
./scripts/make-app.sh
ZIP="build/Sample-Search-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "build/Sample Search.app" "$ZIP"
echo "Zipped $ZIP"
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo "Tag v$VERSION already exists"
else
    git tag -a "v$VERSION" -m "Sample Search $VERSION"
    echo "Tagged v$VERSION (push with: git push origin v$VERSION)"
fi
echo "Next: https://github.com/pluginfox/trigger-search/releases/new?tag=v$VERSION — attach $ZIP"
