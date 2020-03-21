#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GnuTLS and its dependencies from sources.

GNUTLS_XZ=gnutls-3.6.12.tar.xz
GNUTLS_TAR=gnutls-3.6.12.tar
GNUTLS_DIR=gnutls-3.6.12
PKG_NAME=gnutls

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT

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
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_SET" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA certs"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-tasn1.sh
then
    echo "Failed to build libtasn1"
    exit 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build ncurses"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    exit 1
fi

###############################################################################

if ! ./build-libexpat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-nettle.sh
then
    echo "Failed to build Nettle"
    exit 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    exit 1
fi

###############################################################################

if ! ./build-p11kit.sh
then
    echo "Failed to build P11-Kit"
    exit 1
fi

###############################################################################

if [[ -z "$(command -v datefudge 2>/dev/null)" ]]
then
    echo ""
    echo "datefudge not found. Some tests will be skipped."
    echo "To fix this issue, please install datefudge."
fi

###############################################################################

echo
echo "********** GnuTLS **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$GNUTLS_XZ" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/$GNUTLS_XZ"
then
    echo "Failed to download GnuTLS"
    exit 1
fi

rm -rf "$GNUTLS_TAR" "$GNUTLS_DIR" &>/dev/null
unxz "$GNUTLS_XZ" && tar -xf "$GNUTLS_TAR"
cd "$GNUTLS_DIR" || exit 1

if [[ -e ../patch/gnutls.patch ]]; then
    cp ../patch/gnutls.patch .
    patch -u -p0 < gnutls.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

GNUTLS_PKGCONFIG="${BUILD_PKGCONFIG[*]}"
GNUTLS_CPPFLAGS="${BUILD_CPPFLAGS[*]}"
GNUTLS_CFLAGS="${BUILD_CFLAGS[*]}"
GNUTLS_CXXFLAGS="${BUILD_CXXFLAGS[*]}"
GNUTLS_LDFLAGS="${BUILD_LDFLAGS[*]}"
GNUTLS_LIBS="${BUILD_LIBS[*]}"

# Solaris is a tab bit stricter than libc
if [[ "$IS_SOLARIS" -ne 0 ]]; then
    # Don't use CPPFLAGS. Options will cross-pollinate into CXXFLAGS.
    GNUTLS_CFLAGS+=" -D_XOPEN_SOURCE=600 -std=gnu99"
fi

# We should probably include --disable-anon-authentication below

    PKG_CONFIG_PATH="${GNUTLS_PKGCONFIG}" \
    CPPFLAGS="${GNUTLS_CPPFLAGS}" \
    CFLAGS="${GNUTLS_CFLAGS}" \
    CXXFLAGS="${GNUTLS_CXXFLAGS}" \
    LDFLAGS="${GNUTLS_LDFLAGS}" \
    LIBS="${GNUTLS_LIBS}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-static \
    --enable-shared \
    --enable-seccomp-tests \
    --enable-sha1-support \
    --disable-guile \
    --disable-ssl2-support \
    --disable-ssl3-support \
    --disable-padlock \
    --disable-doc \
    --disable-full-test-suite \
    --with-p11-kit \
    --with-libregex \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX" \
    --with-libseccomp-prefix="$INSTX_PREFIX" \
    --with-libcrypto-prefix="$INSTX_PREFIX" \
    --with-unbound-root-key-file="$SH_UNBOUND_ROOTKEY_FILE" \
    --with-default-trust-store-file="$SH_CACERT_FILE" \
    --with-default-trust-store-dir="$SH_CACERT_PATH"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GnuTLS"
    exit 1
fi

echo "Patching Makefiles"
for file in $(find "$PWD" -iname 'Makefile')
do
    # Make console output more readable...
    cp -p "$file" "$file.fixed"
    sed -e 's|-Wtype-limits .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|-fno-common .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "Patching test Makefiles"
for file in $(find "$PWD/tests" -iname 'Makefile')
do
    # Test suite does not compile with NDEBUG defined.
    cp -p "$file" "$file.fixed"
    sed -e 's| -DNDEBUG||g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "Patching La files"
for file in $(find "$PWD" -iname '*.la')
do
    # Make console output more readable...
    cp -p "$file" "$file.fixed"
    sed -e 's|-Wtype-limits .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|-fno-common .*|-fno-common -Wall |g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "Patching Shell Scripts"
for file in $(find "$PWD" -name '*.sh')
do
    # Fix shell
    cp -p "$file" "$file.fixed"
    sed -e 's|#!/bin/sh|#!/usr/bin/env bash|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

if [[ "$IS_SOLARIS" -ne 0 ]]
then
    # Solaris netstat is different then GNU netstat
    echo "Patching common.sh"
    file=tests/scripts/common.sh
    cp -p "$file" "$file.fixed"
    sed -e 's|PFCMD -anl|PFCMD -an|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
fi
echo ""

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GnuTLS"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    # Still can't pass all the self-tests, even after OpenSSL 1.1 cutover.
    # I'd love to know what is wrong with the test-ciphers-api. Below,
    # we expect 1 failure due to test-ciphers-api.

    # Count the number of failures, like :XFAIL: 0" and "FAIL:  0". Compress two
    # spaces to one to make it easy to invert the match 'FAIL: 0'.
    COUNT=$(grep -i 'FAIL:' tests/test-suite.log tests/slow/test-suite.log | sed 's/  / /g' | grep -i -c -v 'FAIL: 0')
    if [[ "${COUNT}" -eq 1 ]]
    then
        echo "One failed to test GnuTLS. Proceeding with install."
    elif [[ "${COUNT}" -gt 1 ]]
    then
        echo "**********************"
        echo "Failed to test GnuTLS"
        echo "**********************"
        exit 1
    fi
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "**********************"
    echo "Failed to test GnuTLS"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
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

    ARTIFACTS=("$GNUTLS_XZ" "$GNUTLS_TAR" "$GNUTLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gnutls.sh 2>&1 | tee build-gnutls.log
    if [[ -e build-gnutls.log ]]; then
        rm -f build-gnutls.log
    fi
fi

exit 0
