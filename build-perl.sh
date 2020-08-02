#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Perl from sources.

# Perl is needed by OpenSSL 1.1.x, but Perl is fragile. We can't install packages
# like HTTP unless it is in a magic directory like `/usr/local`. There's something
# broke with the cpan program that gets built. We need to keep an eye on what
# breaks because of Perl.

# This downloads and installs Perl's package manager. I'm not sure if we should do
# something with it.
#     curl -L http://cpanmin.us | perl - App::cpanminus

PERL_TAR=perl-5.32.0.tar.gz
PERL_DIR=perl-5.32.0
PKG_NAME=perl

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_DONE" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip"
    exit 1
fi

###############################################################################

if ! ./build-bdb.sh
then
    echo "Failed to build Berkeley DB"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Perl ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$PERL_TAR" --ca-certificate="$GLOBALSIGN_ROOT" \
     "https://www.cpan.org/src/5.0/$PERL_TAR"
then
    echo "Failed to download Perl"
    exit 1
fi

rm -rf "$PERL_DIR" &>/dev/null
gzip -d < "$PERL_TAR" | tar xf -
cd "$PERL_DIR" || exit 1

#cp op.c op.c.orig
#cp pp.c pp.c.orig
#cp sv.c sv.c.orig
#cp numeric.c numeric.c.orig
#cp regcomp.c regcomp.c.orig
#cp vms/vms.c vms/vms.c.orig
#cp ext/POSIX/POSIX.xs ext/POSIX/POSIX.xs.orig
#cp cpan/Compress-Raw-Zlib/zlib-src/zutil.c cpan/Compress-Raw-Zlib/zlib-src/zutil.c.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/perl.patch ]]; then
    chmod a+w op.c pp.c sv.c numeric.c regcomp.c vms/vms.c
    chmod a+w ext/POSIX/POSIX.xs
    chmod a+w cpan/Compress-Raw-Zlib/zlib-src/zutil.c

    patch -u -p0 < ../patch/perl.patch
    echo ""

    chmod a-w op.c pp.c sv.c numeric.c regcomp.c vms/vms.c
    chmod a-w ext/POSIX/POSIX.xs
    chmod a-w cpan/Compress-Raw-Zlib/zlib-src/zutil.c
fi

#diff -u op.c.orig op.c > ../patch/perl.patch
#diff -u pp.c.orig pp.c >> ../patch/perl.patch
#diff -u sv.c.orig sv.c >> ../patch/perl.patch
#diff -u numeric.c.orig numeric.c >> ../patch/perl.patch
#diff -u regcomp.c.orig regcomp.c >> ../patch/perl.patch
#diff -u vms/vms.c.orig vms/vms.c >> ../patch/perl.patch
#diff -u ext/POSIX/POSIX.xs.orig ext/POSIX/POSIX.xs >> ../patch/perl.patch
#diff -u cpan/Compress-Raw-Zlib/zlib-src/zutil.c.orig cpan/Compress-Raw-Zlib/zlib-src/zutil.c >> ../patch/perl.patch

# Perl creates files in the user's home directory, but owned by root:root.
# It looks like they are building shit during 'make install'. WTF???
# Note to future maintainers: never build shit during 'make install'.
mkdir -p "$HOME/.cpan"

echo "**********************"
echo "Configuring package"
echo "**********************"

# The HTTP gear breaks on all distros, like Ubuntu 4 and Fedora 32
# https://www.nntp.perl.org/group/perl.beginners/2020/01/msg127308.html
# -Dextras="HTTP::Daemon HTTP::Request Test::More Text::Template"

PERL_PKGCONFIG="${INSTX_PKGCONFIG[*]}"
PERL_CPPFLAGS="${INSTX_CPPFLAGS[*]}"
PERL_ASFLAGS="${INSTX_ASFLAGS[*]}"
PERL_CFLAGS="${INSTX_CFLAGS[*]}"
PERL_CXXFLAGS="${INSTX_CXXFLAGS[*]}"
PERL_LDFLAGS="${INSTX_LDFLAGS[*]}"
PERL_CC="${CC}"; PERL_CXX="${CXX}"

# Perl munges -Wl,-R,'$ORIGIN/../lib'. Somehow it manages
# to escape the '$ORIGIN/../lib' in single quotes. Set $ORIGIN
# to itself to workaround it. Things are still broke, though.
# Also see https://github.com/Perl/perl5/issues/17534
export ORIGIN="\$ORIGIN"

if ! ./Configure -des \
     -Dprefix="$INSTX_PREFIX" \
     -Dlibdir="$INSTX_LIBDIR" \
     -Dpkgconfig="$PERL_PKGCONFIG" \
     -Dcc="$PERL_CC" \
     -Dcxx="$PERL_CXX" \
     -Acppflags="$PERL_CPPFLAGS" \
     -Aasflags="$PERL_ASFLAGS" \
     -Accflags="$PERL_CFLAGS" \
     -Acxxflags="$PERL_CXXFLAGS" \
     -Aldflags="$PERL_LDFLAGS" \
     -Dextras="Test::More Text::Template"
then
    echo "Failed to configure Perl"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

# CPAN uses Make rather than Gmake. It breaks on some of the BSDs.
# Also see https://github.com/Perl/perl5/issues/17543.
export MAKE="${MAKE}"

# Perl has a problem with parallel builds on some paltforms.
if [[ "$IS_NETBSD" -ne 0 ]]; then
    MAKE_FLAGS=("-j" "1")
else
    MAKE_FLAGS=("-j" "$INSTX_JOBS")
fi

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Perl"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# Needed by NetBSD 8.1
export PERL5LIB="$PWD/lib"

MAKE_FLAGS=("check" "-j" "1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test Perl"
    echo "**********************"
    exit 1
fi

# Fix runpaths again
bash ../fix-runpath.sh

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

if [[ -n "$SUDO_PASSWORD" ]]
then
    echo "**********************"
    echo "Fixing permissions"
    echo "**********************"

    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chown -R "$SUDO_USER:$SUDO_USER" "$HOME/.cpan"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

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
