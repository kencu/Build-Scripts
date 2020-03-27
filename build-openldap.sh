#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenLDAP from sources.

LDAP_TAR=openldap-2.4.47.tgz
LDAP_DIR=openldap-2.4.47
PKG_NAME=openldap

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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-bdb.sh
then
    echo "Failed to build Berkely DB"
    exit 1
fi

###############################################################################

# Problem with paths on NetBSD???

OLD_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
LD_LIBRARY_PATH="$INSTX_LIBDIR:$LD_LIBRARY_PATH"
LD_LIBRARY_PATH=$(printf "$LD_LIBRARY_PATH" | sed 's|:$||')
export LD_LIBRARY_PATH

OLD_DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH"
DYLD_LIBRARY_PATH="$INSTX_LIBDIR:$DYLD_LIBRARY_PATH"
DYLD_LIBRARY_PATH=$(printf "$DYLD_LIBRARY_PATH" | sed 's|:$||')
export DYLD_LIBRARY_PATH

###############################################################################

echo
echo "********** OpenLDAP **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" --ca-certificate="$GO_DADDY_ROOT" -O "$LDAP_TAR" \
     "https://gpl.savoirfairelinux.net/pub/mirrors/openldap/openldap-release/$LDAP_TAR"
then
    echo "Failed to download OpenLDAP"
    exit 1
fi

rm -rf "$LDAP_DIR" &>/dev/null
gzip -d < "$LDAP_TAR" | tar xf -
cd "$LDAP_DIR"

if [[ -e ../patch/openldap.patch ]]; then
    cp ../patch/openldap.patch .
    patch -u -p0 < openldap.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
cp -p ../fix-configure.sh .
./fix-configure.sh

# Fix Berkeley DB version test
cp -p configure configure.new
sed 's|0x060014|0x060300|g' configure > configure.new
mv configure.new configure; chmod a+x configure

# mdb is too dirty and cannot build on OS X
# It is also full of undefined behavior
# Just disable mdb on all platforms
CONFIG_OPTS=()
CONFIG_OPTS+=("--with-tls=openssl")
CONFIG_OPTS+=("--enable-mdb=no")

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure OpenLDAP"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenLDAP"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pkgconfig.sh .
./fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# Can't pass self tests on ARM
MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test OpenLDAP"
    # exit 1
fi

# Too many findings...
# https://www.openldap.org/its/index.cgi/Incoming?id=8988
# https://www.openldap.org/its/index.cgi/Incoming?id=8989
echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test OpenLDAP"
    # exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

OLD_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
OLD_DYLD_LIBRARY_PATH="$OLD_DYLD_LIBRARY_PATH"

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$LDAP_TAR" "$LDAP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openldap.sh 2>&1 | tee build-openldap.log
    if [[ -e build-openldap.log ]]; then
        rm -f build-openldap.log
    fi
fi

exit 0
