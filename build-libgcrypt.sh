#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libgcrypt from sources.

GCRYPT_TAR=libgcrypt-1.8.6.tar.bz2
GCRYPT_DIR=libgcrypt-1.8.6
PKG_NAME=libgcrypt
LOG_NAME="${PKG_NAME}.log"

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

if ! ./build-gpgerror.sh
then
    echo "Failed to build Libgpg-error"
    exit 1
fi

###############################################################################

if ! ./build-nPth.sh
then
    echo "Failed to build nPth"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== libgcrypt =============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$GCRYPT_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://gnupg.org/ftp/gcrypt/libgcrypt/$GCRYPT_TAR"
then
    echo "Failed to download libgcrypt"
    exit 1
fi

rm -rf "$GCRYPT_DIR" &>/dev/null
tar xjf "$GCRYPT_TAR"
cd "$GCRYPT_DIR"

# cp tests/Makefile.in tests/Makefile.in.orig

if [[ -e ../patch/libgcrypt.patch ]]; then
    patch -u -p0 < ../patch/libgcrypt.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    ASFLAGS="${INSTX_ASFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --with-libgpg-error-prefix="$INSTX_PREFIX" \
    --with-pth-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libgcrypt"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libgcrypt"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# libgcrypt fails random tests on OS X. Allow one failure
# in random due to SIP. Also see https://dev.gnupg.org/T5009.

MAKE_FLAGS=("check" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}" 2>&1 | tee ${LOG_NAME}
then
    echo "****************************"
    echo "Failed to test libgcrypt (1)"
    echo "****************************"
    bash ../collect-logs.sh
    exit 1
fi

errors=$(grep 'FAIL: ' ${LOG_NAME} | grep -c -v 'FAIL: random')
if [ "$errors" -gt 0 ];
then
    echo "****************************"
    echo "Failed to test libgcrypt (2)"
    echo "****************************"
    bash ../collect-logs.sh
    exit 1
fi

# Fix runpaths
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

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GCRYPT_TAR" "$GCRYPT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-libgcrypt.sh 2>&1 | tee build-libgcrypt.log
    if [[ -e build-libgcrypt.log ]]; then
        rm -f build-libgcrypt.log
    fi
fi

exit 0
