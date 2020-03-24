#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds NGHTTP2 from sources.

NGHTTP2_VER=1.40.0
NGHTTP2_TAR=nghttp2-$NGHTTP2_VER.tar.gz
NGHTTP2_DIR=nghttp2-$NGHTTP2_VER
PKG_NAME=nghttp2

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
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-libxml2.sh
then
    echo "Failed to install libxml2"
    exit 1
fi

###############################################################################

if ! ./build-jansson.sh
then
    echo "Failed to install Jansson"
    exit 1
fi

###############################################################################

if ! ./build-cares.sh
then
    echo "Failed to install c-ares"
    exit 1
fi

###############################################################################

echo
echo "********** NGHTTP2 **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$NGHTTP2_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/nghttp2/nghttp2/releases/download/v$NGHTTP2_VER/$NGHTTP2_TAR"
then
    echo "Failed to download NGHTTP2"
    exit 1
fi

rm -rf "$NGHTTP2_DIR" &>/dev/null
gzip -d < "$NGHTTP2_TAR" | tar xf -
cd "$NGHTTP2_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/nghttp2.patch ]]; then
    cp ../patch/nghttp2.patch .
    patch -u -p0 < nghttp2.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
cp -p ../fix-configure.sh .
./fix-configure.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --disable-assert \
    --with-libxml2 \
    --enable-hpack-tools
    # --enable-app \
    # --enable-lib-only

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure NGHTTP2"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build NGHTTP2"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pkgconfig.sh .
./fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test NGHTTP2"
    echo "**********************"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "**********************"
    echo "Failed to test NGHTTP2"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
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

    ARTIFACTS=("$NGHTTP2_TAR" "$NGHTTP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-nghttp2.sh 2>&1 | tee build-nghttp2.log
    if [[ -e build-nghttp2.log ]]; then
        rm -f build-nghttp2.log
    fi
fi

exit 0
