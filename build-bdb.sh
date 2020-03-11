#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Berkeley DB from sources.

# Note: we do not build with OpenSSL. There is a circular
# dependency between Berkeley DB, OpenSSL and Perl.
# The loss of SSL/TLS in Berkeley DB means the Replication
# Manager does not have SSL/TLS support.

BDB_TAR=db-6.2.32.tar.gz
BDB_DIR=db-6.2.32
PKG_NAME=bdb

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

# OpenLDAP cannot build on NetBSD ???
IS_NETBSD=$(uname -s 2>/dev/null | grep -i -c NetBSD)
IS_NETBSD=0

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

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

echo
echo "********** Berkely DB **********"
echo

cp "bootstrap/$BDB_TAR" .
rm -rf "$BDB_DIR" &>/dev/null
gzip -d < "$BDB_TAR" | tar xf -

cd "$BDB_DIR" || exit 1

cp ../patch/db.patch .
patch -u -p0 < db.patch
echo ""

cd "$CURR_DIR" || exit 1
cd "$BDB_DIR/dist" || exit 1

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

cd "$CURR_DIR" || exit 1
cd "$BDB_DIR" || exit 1

CONFIG_OPTS=()
CONFIG_OPTS+=("--build=$AUTOCONF_BUILD")
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--with-tls=openssl")
CONFIG_OPTS+=("--enable-cxx")

if [ "$IS_NETBSD" -eq 0 ]
then
    CONFIG_OPTS+=("--disable-ldap")
    CONFIG_OPTS+=("--disable-ldaps")
fi

    # Add --with-tls=openssl back in the future
    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
./dist/configure \
    "${CONFIG_OPTS[@]}"
    

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Berkeley DB"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Berkeley DB"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

echo "Unable to test Berkeley DB"

# No check or test recipes
#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Berkeley DB"
#    exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test Berkeley DB"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

# Write the *.pc file
{
    echo ""
    echo "prefix=$INSTX_PREFIX"
    echo "exec_prefix=\${prefix}"
    echo "libdir=$INSTX_LIBDIR"
    echo "sharedlibdir=\${libdir}"
    echo "includedir=\${prefix}/include"
    echo ""
    echo "Name: Berkeley DB"
    echo "Description: Berkeley DB client library"
    echo "Version: 6.2"
    echo ""
    echo "Requires:"
    echo "Libs: -L\${libdir} -ldb"
    echo "Cflags: -I\${includedir}"
} > libdb.pc

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
    echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -S cp libdb.pc "$INSTX_LIBDIR/pkgconfig"
    echo "$SUDO_PASSWORD" | sudo -S chmod 644 "$INSTX_LIBDIR/pkgconfig/libdb.pc"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
    mkdir -p "$INSTX_LIBDIR/pkgconfig"
    cp libdb.pc "$INSTX_LIBDIR/pkgconfig"
    chmod 644 "$INSTX_LIBDIR/pkgconfig/libdb.pc"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$BDB_TAR" "$BDB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openldap.sh 2>&1 | tee build-openldap.log
    if [[ -e build-openldap.log ]]; then
        rm -f build-openldap.log
    fi
fi

exit 0
