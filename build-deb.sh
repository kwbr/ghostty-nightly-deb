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

# Internal format: X.Y.Z+git.HASH (Zig-friendly)
GHOSTTY_INTERNAL_VER="${RAW_VERSION}+git.${GIT_HASH}"
# Debian format: X.Y.Z~nightly+HASH (Sorting-friendly)
DEB_VERSION="${RAW_VERSION}~nightly+${GIT_HASH}"
DEB_VERSION=$(echo "$DEB_VERSION" | tr '-' '~' | tr -d '\n\r ')

echo "--- Building Ghostty: $DEB_VERSION ---"

# 3. Setup Debian Metadata
rm -rf debian && mkdir -p debian

# Copyright File
cat <<EOF > debian/copyright
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: ghostty
Source: https://github.com/ghostty-org/ghostty

Files: *
Copyright: 2024 Mitchell Hashimoto
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
EOF

# Lintian Overrides
cat <<EOF > debian/ghostty.lintian-overrides
# Zig ReleaseFast results in unstripped binaries that we handle manually/skip
ghostty: unstripped-binary-or-object *
# Zig's build system often bundles these or uses specialized paths
ghostty: embedded-library *
ghostty: custom-library-search-path *
# Internal libraries
ghostty: package-name-doesnt-match-sonames *
ghostty: link-to-shared-library-in-wrong-package *
ghostty: no-code-sections *
EOF

# Control File
cat <<EOF > debian/control
Source: ghostty
Section: x11
Priority: optional
Maintainer: $DEBFULLNAME <$DEBEMAIL>
Build-Depends: debhelper-compat (= 13), pkg-config, libgtk-4-dev, libadwaita-1-dev, libgtk4-layer-shell-dev, libfontconfig-dev, libharfbuzz-dev, libpixman-1-dev, blueprint-compiler, pandoc
Standards-Version: 4.6.2

Package: ghostty
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}
Description: GPU-accelerated terminal emulator (Nightly)
 Built from git hash $GIT_HASH with pandoc-generated documentation.
EOF

# Rules File
cat <<EOF > debian/rules
#!/usr/bin/make -f
ZIG = /usr/local/bin/zig
INTERNAL_VER = $GHOSTTY_INTERNAL_VER

%:
	dh \$@

override_dh_auto_build:
	# Use a local zig-out directory to avoid writing to /usr as non-root
	\$(ZIG) build \\
		--summary all \\
		--prefix \$(CURDIR)/zig-out \\
		-Doptimize=ReleaseFast \\
		-Dcpu=baseline \\
		-Dpie=true \\
		-Demit-docs \\
		-Dversion-string=\$(INTERNAL_VER)

override_dh_auto_install:
	# Install to the staging directory by setting --prefix
	\$(ZIG) build \\
		--prefix \$(CURDIR)/debian/ghostty/usr \\
		-Doptimize=ReleaseFast \\
		-Dcpu=baseline \\
		-Dpie=true \\
		-Dversion-string=\$(INTERNAL_VER)
	
	# Clean up hardcoded staging paths in metadata files
	find \$(CURDIR)/debian/ghostty/usr/share -type f \( -name "*.desktop" -o -name "*.service" \) -exec sed -i "s|\$(CURDIR)/debian/ghostty||g" {} +
	
	# Clean up any lingering cache artifacts that Zig might have copied
	find \$(CURDIR)/debian/ghostty -name ".zig-cache" -type d -exec rm -rf {} + || true

override_dh_fixperms:
	dh_fixperms
	# Fix executable bit on desktop files (some environments set it incorrectly)
	find \$(CURDIR)/debian/ghostty/usr/share -name "*.desktop" -exec chmod -x {} +

# Zig ReleaseFast already handles optimization/stripping, 
# and dh_strip often fails on Zig's static library outputs.
override_dh_strip:

override_dh_dwz:
EOF
chmod +x debian/rules

# 4. Build
dch --create --empty --package ghostty -v "$DEB_VERSION" --no-query "Nightly build from git tip $GIT_HASH"
debuild -e PATH -e DEBEMAIL -e DEBFULLNAME -d -us -uc -b

# 5. Export
cp ../ghostty_*.deb /dist/
