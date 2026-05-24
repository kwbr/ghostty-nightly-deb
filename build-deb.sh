#!/bin/bash
set -e

# Identity for Debian tools
export DEBEMAIL="nightly@ghostty.org"
export DEBFULLNAME="Ghostty Nightly Builder"

# 1. Source Persistence & Update
if [ ! -d "source/.git" ]; then
    git clone --depth 1 https://github.com/ghostty-org/ghostty.git source
fi
cd source
git fetch origin main
git reset --hard origin/main

# 2. Extract Versions
RAW_VERSION=$(grep -m 1 "^\s*\.version =" build.zig.zon | cut -d '"' -f 2 | sed 's/^\.//')
GIT_HASH=$(git rev-parse --short HEAD)

# Debian format: X.Y.Z~nightly+HASH (Sorting-friendly)
DEB_VERSION="${RAW_VERSION}~nightly+${GIT_HASH}"
DEB_VERSION=$(echo "$DEB_VERSION" | tr '-' '~' | tr -d '\n\r ')

echo "--- Building Ghostty: $DEB_VERSION ---"

# 3. Setup Debian Metadata
rm -rf debian
cp -r /build/debian ./
sed -i "s/@GIT_HASH@/$GIT_HASH/g" debian/control

# 4. Build
dch --create --empty --package ghostty -v "$DEB_VERSION" --no-query "Nightly build from git tip $GIT_HASH"
debuild -e PATH -e DEBEMAIL -e DEBFULLNAME -d -us -uc -b

# 5. Export
cp ../ghostty_*.deb /dist/
