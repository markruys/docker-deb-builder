#!/bin/bash -e

# This script is executed within the container as root.  It assumes
# that source code with debian packaging files can be found at
# /source-ro and that resulting packages are written to /output after
# succesful build.  These directories are mounted as docker volumes to
# allow files to be exchanged between the host and the container.

# Install extra dependencies that were provided for the build (if any)
#   Note: dpkg can fail due to dependencies, ignore errors, and use
#   apt-get to install those afterwards
[[ -d /dependencies ]] && dpkg -i /dependencies/*.deb || apt-get -f install -y --no-install-recommends

# Make read-write copy of source code
if [ -f /build/*.orig.tar.gz ]; then
    mkdir -p /build/source
    tar xzf /build/*.orig.tar.gz --strip-components=1 -C /build/source
    debuild_args=""
elif [ -d source-ro ]; then
    mkdir -p /build
    cp -a /source-ro /build/source
    debuild_args="-b"
else
    echo "No source found -- aborting"
    exit 1
fi
cd /build/source

# Install build dependencies
mk-build-deps -ir -t "apt-get -o Debug::pkgProblemResolver=yes -y --no-install-recommends"

# Add a record to the changelog
if [ -n "$DEBFULLNAME" -a -n "$DEBEMAIL" ]; then
	VERSION=$(awk -F '=' '/^VERSION=/{print $2}' /etc/os-release)
	VERSION_CODENAME=$(awk -F '=' '/^VERSION_CODENAME=/{print $2}' /etc/os-release)
	dch -l "$VERSION_CODENAME" "Build for $VERSION"
fi

# Build packages
debuild $debuild_args -uc -us

# Copy packages to output dir with user's permissions
find /build \( -name '*.deb' -o -name '*.dsc' -o -name '*.tar.*' \) -type f -exec cp -a {} /output/ \;
chown -R $USER:$GROUP /output
ls -l /output
