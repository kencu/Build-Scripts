#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Unbound from sources.

UNBOUND_VER=1.12.0
UNBOUND_TAR="unbound-${UNBOUND_VER}.tar.gz"
UNBOUND_DIR="unbound-${UNBOUND_VER}"
PKG_NAME=unbound

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

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-libexpat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-nettle.sh
then
    echo "Failed to build Nettle"
    exit 1
fi

###############################################################################

if ! ./build-hiredis.sh
then
    echo "Failed to build Hiredis"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

# Copy icannbundle.pem and rootkey.pem from bootstrap/
if ! ./build-rootkey.sh
then
    echo "Failed to update Unbound Root Key"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ Unbound ==============="
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

if ! "$WGET" -q -O "$UNBOUND_TAR" --ca-certificate="$IDENTRUST_ROOT" \
     "https://unbound.net/downloads/$UNBOUND_TAR"
then
    echo "Failed to download Unbound"
    exit 1
fi

rm -rf "$UNBOUND_DIR" &>/dev/null
gzip -d < "$UNBOUND_TAR" | tar xf -
cd "$UNBOUND_DIR" || exit 1

if [[ -e ../patch/unbound.patch ]]; then
    patch -u -p0 < ../patch/unbound.patch
    echo ""
fi

# A small patch
echo "Patching unbound-anchor.c"
wget -q -O smallapp/unbound-anchor.c https://raw.githubusercontent.com/noloader/unbound/master/smallapp/unbound-anchor.c

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "***************************"
echo "Configuring package"
echo "***************************"

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
    --enable-static-exe \
    --enable-shared \
    --with-rootkey-file="$OPT_UNBOUND_ROOTKEY_FILE" \
    --with-rootcert-file="$OPT_UNBOUND_ICANN_FILE" \
    --with-ssl="$INSTX_PREFIX" \
    --with-libexpat="$INSTX_PREFIX" \
    --with-libhiredis="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]
then
    echo "***************************"
    echo "Failed to configure Unbound"
    echo "***************************"

    bash ../collect-logs.sh
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to build Unbound"
    echo "***************************"

    bash ../collect-logs.sh
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "***************************"
echo "Testing package"
echo "***************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to test Unbound"
    echo "***************************"

    bash ../collect-logs.sh
    exit 1
fi

echo "***************************"
echo "Installing package"
echo "***************************"

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
if true;
then
    ARTIFACTS=("$UNBOUND_TAR" "$UNBOUND_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

###############################################################################

exit 0
