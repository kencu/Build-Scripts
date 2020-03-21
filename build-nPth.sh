#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds npth from sources.

NPTH_TAR=npth-1.6.tar.bz2
NPTH_DIR=npth-1.6
PKG_NAME=npth

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
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

if [[ -e "$INSTX_PACKAGE_CACHE/$PKG_NAME" ]]; then
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

echo
echo "********** npth **********"
echo

if ! "$WGET" -O "$NPTH_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://gnupg.org/ftp/gcrypt/npth/$NPTH_TAR"
then
    echo "Failed to download npth"
    exit 1
fi

rm -rf "$NPTH_DIR" &>/dev/null
tar xjf "$NPTH_TAR"
cd "$NPTH_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    BUILD_STD="-std=c99"
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]} $BUILD_STD" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --enable-shared \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure npth"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build npth"
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
    echo "Failed to test npth"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test npth"
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

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PACKAGE_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$NPTH_TAR" "$NPTH_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-npth.sh 2>&1 | tee build-npth.log
    if [[ -e build-npth.log ]]; then
        rm -f build-npth.log
    fi
fi

exit 0
