#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libxml2 from sources.

XML2_TAR=libxml2-2.9.10.tar.gz
XML2_DIR=libxml2-2.9.10
PKG_NAME=libxml2

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

if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

echo
echo "********** libxml2 **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$XML2_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
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
    patch -u -p0 < ../patch/libxml2.patch
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
    --enable-static --enable-shared \
    --with-fexceptions \
    --with-iconv="$INSTX_PREFIX" \
    --without-legacy \
    --without-python \
    --with-zlib="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libxml2"
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
    echo "Failed to build libxml2"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test libxml2"
    echo "**********************"
    exit 1
fi

# Fix runpaths again
bash ../fix-runpath.sh

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
