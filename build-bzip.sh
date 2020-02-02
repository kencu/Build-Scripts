#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Bzip2 from sources.

# shellcheck disable=SC2191

# Bzip lost its website. It is now located on Sourceware.

BZIP2_TAR=bzip2-1.0.8.tar.gz
BZIP2_DIR=bzip2-1.0.8
PKG_NAME=bzip2

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

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

echo
echo "********** Bzip **********"
echo

if ! "$WGET" -O "$BZIP2_TAR" \
     "ftp://sourceware.org/pub/bzip2/$BZIP2_TAR"
then
    echo "Failed to download Bzip"
    exit 1
fi

rm -rf "$BZIP2_DIR" &>/dev/null
gzip -d < "$BZIP2_TAR" | tar xf -
cd "$BZIP2_DIR" || exit 1

# The Makefiles needed so much work it was easier to rewrite them.
cp ../patch/bzip-makefiles.zip .
unzip -aoq bzip-makefiles.zip

# Now, patch them for this script.
cp ../patch/bzip.patch .
patch -u -p0 < bzip.patch
echo ""

echo "**********************"
echo "Building package"
echo "**********************"

if [[ "$IS_DARWIN" -ne 0 ]]; then
    MAKEFILE=Makefile-libbz2_dylib
else
    MAKEFILE=Makefile-libbz2_so
fi

MAKE_FLAGS=("-f" "Makefile" "-j" "$INSTX_JOBS"
            CC="${CC}" CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip archive"
    exit 1
fi

MAKE_FLAGS=("-f" "$MAKEFILE" "-j" "$INSTX_JOBS"
            CC="${CC}" CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Bzip shared object"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("-f" "Makefile" "check" "-j" "$INSTX_JOBS"
            CC="${CC}" CFLAGS="${BUILD_CFLAGS[*]} -I."
            LDFLAGS="${BUILD_LDFLAGS[*]}")

if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Bzip"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Bzip"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

# Write the *.pc file
{
    echo ""
    echo "prefix=$INSTX_PREFIX"
    echo "exec_prefix=\${prefix}"
    echo "libdir=$INSTX_LIBDIR"
    echo "includedir=\${prefix}/include"
    echo ""
    echo "Name: Berkeley DB"
    echo "Description: Bzip2 client library"
    echo "Version: 1.0.8"
    echo ""
    echo "Requires:"
    echo "Libs: -L\${libdir} -lbz2"
    echo "Cflags: -I\${includedir}"
} > libbz2.pc

if [[ -n "$SUDO_PASSWORD" ]]; then
    MAKE_FLAGS=("-f" "Makefile" install PREFIX="$INSTX_PREFIX")
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "$MAKEFILE" install PREFIX="$INSTX_PREFIX")
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"

    echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -S cp libbz2.pc "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -S chmod 644 "$INSTX_LIBDIR/pkgconfig/libbz2.pc"
else
    MAKE_FLAGS=("-f" "Makefile" install PREFIX="$INSTX_PREFIX")
    "$MAKE" "${MAKE_FLAGS[@]}"

    MAKE_FLAGS=("-f" "$MAKEFILE" install PREFIX="$INSTX_PREFIX")
    "$MAKE" "${MAKE_FLAGS[@]}"

    mkdir -p "$INSTX_LIBDIR/pkgconfig"
    cp libbz2.pc "$INSTX_LIBDIR/pkgconfig"
    chmod 644 "$INSTX_LIBDIR/pkgconfig/libbz2.pc"
fi

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

    ARTIFACTS=("$BZIP2_TAR" "$BZIP2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-bzip.sh 2>&1 | tee build-bzip.log
    if [[ -e build-bzip.log ]]; then
        rm -f build-bzip.log
    fi
fi

exit 0
