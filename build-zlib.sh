#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds zLib from sources.

ZLIB_TAR=zlib-1.2.11.tar.gz
ZLIB_DIR=zlib-1.2.11
PKG_NAME=zlib

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:-2}"

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
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

# zLib does not need patchelf. However, many of the programs and libraries
# that depend on zLib need it. Build it here for the sake of convenience.
if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

echo
echo "********** zLib **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$ZLIB_TAR" \
     "http://www.zlib.net/$ZLIB_TAR"
then
    echo "Failed to download zLib"
    exit 1
fi

rm -rf "$ZLIB_DIR" &>/dev/null
gzip -d < "$ZLIB_TAR" | tar xf -
cd "$ZLIB_DIR" || exit 1

# cp gzguts.h gzguts.h.orig
# cp trees.c trees.c.orig
# cp Makefile.in Makefile.in.orig
# cp configure configure.orig

if [[ -e ../patch/zlib.patch ]]; then
    patch -u -p0 < ../patch/zlib.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CC="${CC}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    ASFLAGS="${INSTX_ASFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
./configure \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --static \
    --shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure zLib"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "all")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build zLib"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build zLib"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
MAKE_FLAGS+=("prefix=$INSTX_PREFIX")
MAKE_FLAGS+=("libdir=$INSTX_LIBDIR")
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

    ARTIFACTS=("$ZLIB_TAR" "$ZLIB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-zlib.sh 2>&1 | tee build-zlib.log
    if [[ -e build-zlib.log ]]; then
        rm -f build-zlib.log
    fi
fi

exit 0
