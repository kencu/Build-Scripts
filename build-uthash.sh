#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds UT Hash from sources.

UTHASH_VER="2.1.0"
UTHASH_TAR="v$UTHASH_VER.tar.gz"
UTHASH_DIR="uthash-$UTHASH_VER"
PKG_NAME=uthash

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
echo "********** UT Hash **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$UTHASH_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/troydhanson/uthash/archive/$UTHASH_TAR"
then
    echo "Failed to download UT Hash"
    exit 1
fi

rm -rf "$UTHASH_DIR" &>/dev/null
gzip -d < "$UTHASH_TAR" | tar xf -
cd "$UTHASH_DIR"

if [[ -e ../patch/uthash.patch ]]; then
    patch -u -p0 < ../patch/uthash.patch
    echo ""
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# No Autotools or makefile in src/
cd tests

MAKE_FLAGS=("-j" "$INSTX_JOBS")
MAKE_FLAGS+=("PKG_CONFIG_PATH=${INSTX_PKGCONFIG[*]}")
MAKE_FLAGS+=("CPPFLAGS=${INSTX_CPPFLAGS[*]}")
MAKE_FLAGS+=("ASFLAGS=${INSTX_ASFLAGS[*]}")
MAKE_FLAGS+=("CFLAGS=${INSTX_CFLAGS[*]}")
MAKE_FLAGS+=("CXXFLAGS=${INSTX_CXXFLAGS[*]}")
MAKE_FLAGS+=("LDFLAGS=${INSTX_LDFLAGS[*]}")
MAKE_FLAGS+=("LIBS=${INSTX_LIBS[*]}")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test UT Hash"
   exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Installing package"
echo "**********************"

cd ../src/

if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S cp *.h "$INSTX_PREFIX/include/"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
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

    ARTIFACTS=("$UTHASH_TAR" "$UTHASH_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-uthash.sh 2>&1 | tee build-uthash.log
    if [[ -e build-uthash.log ]]; then
        rm -f build-uthash.log
    fi
fi

exit 0
