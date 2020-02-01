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

# The password should die when this subshell goes out of scope
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

# See if AES-NI and SHA are available in the compiler
AESNI_OPT=$("$CC" -dM -E -maes - </dev/null 2>&1 | grep -i -c "__AES__")
SHANI_OPT=$("$CC" -dM -E -msha - </dev/null 2>&1 | grep -i -c "__SHA__")

###############################################################################

echo
echo "********** Nettle **********"
echo

if ! "$WGET" -O "$NETTLE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
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
../fix-config.sh

for file in $(find "$PWD" -name 'Makefile' -name 'Makefile.in' -name 'configure')
do
    sed 's/ -ggdb3//g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

# Awful Solaris 64-bit hack. Rewrite some values
if [[ "$IS_SOLARIS" -eq 1 ]]; then
    # Solaris requires -shared for shared object
    sed 's| -G -h| -shared -h|g' configure.ac > configure.ac.fixed
    mv configure.ac.fixed configure.ac; chmod +x configure.ac
    touch -t 197001010000 configure.ac
fi

CONFIG_OPTS=()
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--disable-documentation")

if [[ "$IS_SOLARIS" -eq 1 ]]
then
    if [[ "$INSTX_BITNESS" -eq 64 && "$IS_AMD64" -eq 1 ]]; then
        CONFIG_OPTS+=(--host=amd64-sun-solaris)
    fi
fi

if [[ "$IS_IA32" -ne 0 && "$AESNI_OPT" -eq 1 ]]; then
    CONFIG_OPTS+=("--enable-x86-aesni")
fi

if [[ "$IS_IA32" -ne 0 && "$SHANI_OPT" -eq 1 ]]; then
    CONFIG_OPTS+=("--enable-x86-sha-ni")
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
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

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
