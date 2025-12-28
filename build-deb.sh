#!/bin/bash
set -e

# Identity for Debian tools
export DEBEMAIL="builder@internal.docker"
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
	\$(ZIG) build \\
		--summary all \\
		--prefix /usr \\
		-Doptimize=ReleaseFast \\
		-Dcpu=baseline \\
		-Dpie=true \\
		-Demit-docs \\
		-Dversion-string=\$(INTERNAL_VER)

override_dh_auto_install:
	DESTDIR=\$(CURDIR)/debian/ghostty \\
	\$(ZIG) build \\
		--prefix /usr \\
		-Doptimize=ReleaseFast \\
		-Dcpu=baseline \\
		-Dpie=true \\
		-Dversion-string=\$(INTERNAL_VER)
EOF
chmod +x debian/rules

# 4. Build
dch --create --empty --package ghostty -v "$DEB_VERSION" --no-query "Nightly build from git tip $GIT_HASH"
debuild -e PATH -e DEBEMAIL -e DEBFULLNAME -d -us -uc -b

# 5. Export
cp ../ghostty_*.deb /dist/
