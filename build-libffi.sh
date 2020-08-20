#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Libffi from sources.

LIBFFI_TAR=libffi-3.2.1.tar.gz
LIBFFI_DIR=libffi-3.2.1
PKG_NAME=libffi

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

# Sets the number of make jobs if not set in environment
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

echo ""
echo "========================================"
echo "================ libffi ================"
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$LIBFFI_TAR" --ca-certificate="$DIGICERT_ROOT" \
     "ftp://sourceware.org/pub/libffi/$LIBFFI_TAR"
then
    echo "Failed to download libffi"
    exit 1
fi

rm -rf "$LIBFFI_DIR" &>/dev/null
gzip -d < "$LIBFFI_TAR" | tar xf -
cd "$LIBFFI_DIR"

# cp src/x86/ffi64.c src/x86/ffi64.c.old

if [[ -e ../patch/libffi.patch ]]; then
    patch -u -p0 < ../patch/libffi.patch
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
    --enable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libffi"
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
    echo "Failed to build libffi"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test libffi"
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
if true; then

    ARTIFACTS=("$LIBFFI_TAR" "$LIBFFI_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-libffi.sh 2>&1 | tee build-libffi.log
    if [[ -e build-libffi.log ]]; then
        rm -f build-libffi.log
    fi
fi

exit 0
