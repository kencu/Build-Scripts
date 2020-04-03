#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Datefudge from sources.

DATEFUDGE_XZ=datefudge_1.22.tar.xz
DATEFUDGE_TAR=datefudge_1.22.tar
DATEFUDGE_DIR=datefudge-1.22
PKG_NAME=datefudge

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
echo "********** Datefudge **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$DATEFUDGE_XZ" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "http://deb.debian.org/debian/pool/main/d/datefudge/$DATEFUDGE_XZ"
then
    echo "Failed to download Datefudge"
    exit 1
fi

rm -rf "$DATEFUDGE_TAR" "$DATEFUDGE_DIR" &>/dev/null
unxz "$DATEFUDGE_XZ" && tar -xf "$DATEFUDGE_TAR"
cd "$DATEFUDGE_DIR"

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

#cp Makefile Makefile.orig
#cp datefudge.c datefudge.c.orig

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    if [[ -e ../patch/datefudge-solaris.patch ]]; then
        patch -u -p0 < ../patch/datefudge-solaris.patch
        echo ""
    fi
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! CC="${CC}" CFLAGS="${BUILD_CFLAGS[*]}" LDFLAGS="${BUILD_LDFLAGS[*]}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Datefudge"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("test" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Datefudge"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "prefix=$INSTX_PREFIX" "libdir=$INSTX_LIBDIR")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$DATEFUDGE_XZ" "$DATEFUDGE_TAR" "$DATEFUDGE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-datefudge.sh 2>&1 | tee build-datefudge.log
    if [[ -e build-datefudge.log ]]; then
        rm -f build-datefudge.log
    fi
fi

exit 0
