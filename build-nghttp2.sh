#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds NGHTTP2 from sources.

NGHTTP2_VER=1.41.0
NGHTTP2_TAR=nghttp2-$NGHTTP2_VER.tar.gz
NGHTTP2_DIR=nghttp2-$NGHTTP2_VER
PKG_NAME=nghttp2

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

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

# c-ares needs a C++11 compiler
if [[ "$INSTX_CXX11" -ne 0 ]]
then
    ENABLE_CARES=1
else
    ENABLE_CARES=0
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

if [[ "$ENABLE_CARES" -eq 1 ]]
then
    if ! ./build-cares.sh
    then
        echo "Failed to build c-ares"
        exit 1
    fi
fi

###############################################################################

echo ""
echo "========================================"
echo "================ NgHTTP2 ==============="
echo "========================================"

echo ""
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
    patch -u -p0 < ../patch/nghttp2.patch
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
    --disable-assert \
    --with-libxml2 \
    --enable-hpack-tools
    # --enable-app \
    # --enable-lib-only

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure NGHTTP2"
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
    echo "Failed to build NGHTTP2"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
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
