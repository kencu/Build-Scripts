#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Nettle from sources.

NETTLE_TAR=nettle-3.5.1.tar.gz
NETTLE_DIR=nettle-3.5.1
PKG_NAME=nettle

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

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo
echo "********** Nettle **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$NETTLE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/nettle/$NETTLE_TAR"
then
    echo "Failed to download Nettle"
    exit 1
fi

rm -rf "$NETTLE_DIR" &>/dev/null
gzip -d < "$NETTLE_TAR" | tar xf -
cd "$NETTLE_DIR" || exit 1

if [[ -e ../patch/nettle.patch ]]; then
    cp ../patch/nettle.patch .
    patch -u -p0 < nettle.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

# Awful Solaris 64-bit hack. Use -G for SunC, and -shared for GCC
if [[ "$IS_SOLARIS" -ne 0 && "$IS_SUNC" -eq 0 ]]; then
    sed 's/ -G / -shared /g' configure > configure.fixed
    mv configure.fixed configure; chmod +x configure
fi

CONFIG_OPTS=()
CONFIG_OPTS+=("--build=$AUTOCONF_BUILD")
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--disable-documentation")

# Work-around Solaris configuration bug. Nettle tries to build SHA,
# even when the compiler does not support it.

if [[ "$IS_IA32" -eq 1 && "$IS_SOLARIS" -eq 0 ]]
then

    AESNI_OPT=$("$CC" "${BUILD_CFLAGS[@]}" -dM -E -maes - </dev/null 2>&1 | grep -i -c "__AES__")
    SHANI_OPT=$("$CC" "${BUILD_CFLAGS[@]}" -dM -E -msha - </dev/null 2>&1 | grep -i -c "__SHA__")

    if [[ "$AESNI_OPT" -ne 0 ]]; then
        echo "Compiler supports AES-NI. Adding --enable-x86-aesni"
        CONFIG_OPTS+=("--enable-x86-aesni")
    fi

    if [[ "$SHANI_OPT" -ne 0 ]]; then
        echo "Compiler supports SHA-NI. Adding --enable-x86-sha-ni"
        CONFIG_OPTS+=("--enable-x86-sha-ni")
    fi

    echo "Using runtime algorithm selection. Adding --enable-fat"; echo ""
    CONFIG_OPTS+=("--enable-fat")
fi

if [[ "$IS_ARM_NEON" -eq 1 ]]
then

    NEON_OPT=$("$CC" "${BUILD_CFLAGS[@]}" -dM -E - </dev/null 2>&1 | grep -i -c "__NEON__")

    if [[ "$NEON_OPT" -ne 0 ]]; then
        echo "Compiler supports ARM NEON. Adding --enable-arm-neon"
        CONFIG_OPTS+=("--enable-arm-neon")
    fi

    echo "Using runtime algorithm selection. Adding --enable-fat"; echo ""
    CONFIG_OPTS+=("--enable-fat")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Nettle"
    exit 1
fi

# Fix LD_LIBRARY_PATH and DYLD_LIBRARY_PATH
../fix-library-path.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Nettle"
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
    echo "Failed to test Nettle"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Nettle"
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

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$NETTLE_TAR" "$NETTLE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-nettle.sh 2>&1 | tee build-nettle.log
    if [[ -e build-nettle.log ]]; then
        rm -f build-nettle.log
    fi
fi

exit 0
