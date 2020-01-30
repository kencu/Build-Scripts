#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Perl from sources.

# Perl is needed by OpenSSL 1.1.x, but Perl is very fragile. Perl can't seem to
# configure/install itself anywhere except magic directories like /usr/local.
# We also can't install packages like HTTP. There's something broke with the cpan
# program that gets built. We need to keep an eye on what breaks because of Perl.

PERL_TAR=perl-5.30.1.tar.gz
PERL_DIR=perl-5.30.1
PKG_NAME=perl

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-bdb.sh
then
    echo "Failed to build Berkeley DB"
    exit 1
fi

###############################################################################

echo
echo "********** Perl **********"
echo

if ! "$WGET" -O "$PERL_TAR" --ca-certificate="$GLOBALSIGN_ROOT" \
     "http://www.cpan.org/src/5.0/$PERL_TAR"
then
    echo "Failed to download Perl"
    exit 1
fi

rm -rf "$PERL_DIR" &>/dev/null
gzip -d < "$PERL_TAR" | tar xf -
cd "$PERL_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/perl.patch ]]; then
    cp ../patch/perl.patch .
    patch -u -p0 < perl.patch
    echo ""
fi

# The HTTP gear breaks on all distros, like Ubuntu 4 and Fedora 32
# It looks like Perl is building shit during 'make install'.
# -Dextras="HTTP::Daemon HTTP::Request Test::More Text::Template"

PERL_PKGCONFIG="${BUILD_PKGCONFIG[*]}"
PERL_CPPFLAGS="${BUILD_CPPFLAGS[*]}"
PERL_CFLAGS="${BUILD_CFLAGS[*]}"
PERL_LDFLAGS="${BUILD_LDFLAGS[*]}"

if ! ./Configure -des \
     -Dprefix="$INSTX_PREFIX" \
     -Dlibdir="$INSTX_LIBDIR" \
     -Dpkgconfig="$PERL_PKGCONFIG" \
     -Acppflags="$PERL_CPPFLAGS" \
     -Accflags="$PERL_CFLAGS" \
     -Aldflags="$PERL_LDFLAGS" \
     -Dextras="Test::More Text::Template"
then
    echo "Failed to configure Perl"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Perl"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=(check)
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    # Perl can't pass its self-tests.
    # https://github.com/Perl/perl5/issues/17508
    echo "**********************"
    echo "Failed to test Perl"
    echo "Installing anyway..."
    echo "**********************"
    # exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    # Perl can't pass its self-tests.
    # https://github.com/Perl/perl5/issues/17508
    echo "**********************"
    echo "Failed to test Perl"
    echo "Installing anyway..."
    echo "**********************"
    # exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

# This downloads and installs Perl's package manager
# curl -L http://cpanmin.us | perl - App::cpanminus

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PERL_TAR" "$PERL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-perl.sh 2>&1 | tee build-perl.log
    if [[ -e build-perl.log ]]; then
        rm -f build-perl.log
    fi
fi

exit 0
