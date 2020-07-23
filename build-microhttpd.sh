#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds MicroHttpd from sources.

HTTPD_TAR=libmicrohttpd-0.9.70.tar.gz
HTTPD_DIR=libmicrohttpd-0.9.70
PKG_NAME=microhttpd

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

if ! ./build-libgcrypt.sh
then
    echo "Failed to install Libgcrypt"
    exit 1
fi

###############################################################################

if ! ./build-curl.sh
then
    echo "Failed to install cURL"
    exit 1
fi

###############################################################################

if ! ./build-gnutls.sh
then
    echo "Failed to install GnuTLS"
    exit 1
fi

###############################################################################

echo
echo "********** MicroHttpd **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$HTTPD_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/libmicrohttpd/$HTTPD_TAR"
then
    echo "Failed to download MicroHttpd"
    exit 1
fi

rm -rf "$HTTPD_DIR" &>/dev/null
gzip -d < "$HTTPD_TAR" | tar xf -
cd "$HTTPD_DIR" || exit 1

# exit 0

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/httpd.patch ]]; then
    patch -u -p0 < ../patch/httpd.patch
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
    --enable-shared=yes \
    --enable-static=yes \
    --enable-https \
    --with-libgcrypt-prefix="$INSTX_PREFIX" \
    --with-libgnutls="$INSTX_PREFIX" \
    --with-libcurl="$INSTX_PREFIX" \
    --disable-doc \
    --disable-examples

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure MicroHttpd"
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
    echo "Failed to build MicroHttpd"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "*************************"
    echo "Failed to test MicroHttpd"
    echo "*************************"
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

    ARTIFACTS=("$HTTPD_TAR" "$HTTPD_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-httpd.sh 2>&1 | tee build-httpd.log
    if [[ -e build-httpd.log ]]; then
        rm -f build-httpd.log
    fi
fi

exit 0
