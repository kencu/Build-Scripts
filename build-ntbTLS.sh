#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds ntbTLS from sources.

NTBTLS_VER=0.2.0
NTBTLS_TAR="ntbtls-${NTBTLS_VER}.tar.bz2"
NTBTLS_DIR="ntbtls-${NTBTLS_VER}"
PKG_NAME=ntbtls

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

INSTX_JOBS="${INSTX_JOBS:-2}"

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-gpgerror.sh
then
    echo "Failed to build libgpg-error"
    exit 1
fi

###############################################################################

if ! ./build-libgcrypt.sh
then
    echo "Failed to build libgpg-gcrypt"
    exit 1
fi

###############################################################################

if ! ./build-libksba.sh
then
    echo "Failed to build libksba"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ ntbTLS ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$NTBTLS_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://gnupg.org/ftp/gcrypt/ntbtls/$NTBTLS_TAR"
then
    echo "Failed to download ntbTLS"
    exit 1
fi

rm -rf "$NTBTLS_DIR" &>/dev/null
tar xjf "$NTBTLS_TAR"
cd "$NTBTLS_DIR"

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    ASFLAGS="${INSTX_ASFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]} $INSTX_STD" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --with-zlib="$INSTX_PREFIX" \
    --with-libgpg-error-prefix="$INSTX_PREFIX" \
    --with-libgcrypt-prefix="$INSTX_PREFIX" \
    --with-ksba-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "**************************"
    echo "Failed to configure ntbTLS"
    echo "**************************"
    bash ../collect-logs.sh
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**************************"
    echo "Failed to build ntbTLS"
    echo "**************************"
    bash ../collect-logs.sh
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**************************"
    echo "Failed to test ntbTLS"
    echo "**************************"
    bash ../collect-logs.sh
    exit 1
fi

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
if true;
then
    ARTIFACTS=("$NTBTLS_TAR" "$NTBTLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
