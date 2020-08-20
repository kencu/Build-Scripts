#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Expat from sources.

# Fix the download URL below when updating versions.
EXPAT_TAR=expat-2.2.9.tar.bz2
EXPAT_DIR=expat-2.2.9
PKG_NAME=expat

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
echo "=============== libexpat ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$EXPAT_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/libexpat/libexpat/releases/download/R_2_2_9/$EXPAT_TAR"
then
    echo "Failed to download libexpat"
    exit 1
fi

rm -rf "$EXPAT_DIR" &>/dev/null
bzip2 -dk < "$EXPAT_TAR" | tar xf -
cd "$EXPAT_DIR" || exit 1

if [[ -e ../patch/expat.patch ]]; then
    patch -u -p0 < ../patch/expat.patch
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
./configure --enable-shared \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --without-docbook \
    --without-xmlwf

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libexpat"
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
    echo "Failed to build libexpat"
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
    echo "Failed to test libexpat"
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

    ARTIFACTS=("$EXPAT_TAR" "$EXPAT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-libexpat.sh 2>&1 | tee build-expat.log
    if [[ -e build-expat.log ]]; then
        rm -f build-expat.log
    fi
fi

exit 0
