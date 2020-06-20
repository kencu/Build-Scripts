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
echo "********** Berkely DB **********"
echo

echo "**********************"
echo "Copying package"
echo "**********************"

cp "bootstrap/$BDB_TAR" "$PWD"
rm -rf "$BDB_DIR" &>/dev/null
gzip -d < "$BDB_TAR" | tar xf -

cd "$BDB_DIR" || exit 1

if [[ -e ../patch/db.patch ]]; then
    patch -u -p0 < ../patch/db.patch
    echo ""
fi

cd "$CURR_DIR" || exit 1
cd "$BDB_DIR/dist" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

cd "$CURR_DIR" || exit 1
cd "$BDB_DIR" || exit 1

    # Add --with-tls=openssl back in the future
    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
./dist/configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --with-tls=openssl \
    --enable-cxx

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Berkeley DB"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Berkeley DB"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

echo "Unable to test Berkeley DB"

# No check or test recipes
#MAKE_FLAGS=("check" "V=1")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
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
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S mkdir -p "$INSTX_LIBDIR/pkgconfig"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S cp libdb.pc "$INSTX_LIBDIR/pkgconfig"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chmod 644 "$INSTX_LIBDIR/pkgconfig/libdb.pc"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    mkdir -p "$INSTX_LIBDIR/pkgconfig"
    cp libdb.pc "$INSTX_LIBDIR/pkgconfig"
    chmod 644 "$INSTX_LIBDIR/pkgconfig/libdb.pc"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

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
