#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libxml2 from sources.

XML2_TAR=libxml2-2.9.10.tar.gz
XML2_DIR=libxml2-2.9.10

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
echo "********** libxml2 **********"
echo

if ! "$WGET" -O "$XML2_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "ftp://xmlsoft.org/libxml2/$XML2_TAR"
then
    echo "Failed to download libxml2"
    exit 1
fi

rm -rf "$XML2_DIR" &>/dev/null
gzip -d < "$XML2_TAR" | tar xf -
cd "$XML2_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/libxml2.patch ]]; then
    cp ../patch/libxml2.patch .
    patch -u -p0 < libxml2.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --with-fexceptions \
    --without-legacy \
    --without-python \
    --with-zlib="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libxml2"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libxml2"
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
    echo "**********************"
    echo "Failed to test libxml2"
    echo "**********************"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "**********************"
    echo "Failed to test libxml2"
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

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$XML2_TAR" "$XML2_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-libxml2.sh 2>&1 | tee build-libxml2.log
    if [[ -e build-libxml2.log ]]; then
        rm -f build-libxml2.log
    fi
fi

exit 0