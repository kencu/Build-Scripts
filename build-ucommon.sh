#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds ucommon from sources.

UCOMMON_TAR=ucommon-7.0.0.tar.gz
UCOMMON_DIR=ucommon-7.0.0
PKG_NAME=ucommon

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:-2}"

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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo
echo "********** ucommon **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$UCOMMON_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/commoncpp/$UCOMMON_TAR"
then
    echo "Failed to download ucommon"
    exit 1
fi

rm -rf "$UCOMMON_DIR" &>/dev/null
gzip -d < "$UCOMMON_TAR" | tar xf -
cd "$UCOMMON_DIR" || exit 1

if false; then
cp openssl/digest.cpp openssl/digest.cpp.orig
cp openssl/random.cpp openssl/random.cpp.orig
cp openssl/cipher.cpp openssl/cipher.cpp.orig
cp openssl/hmac.cpp openssl/hmac.cpp.orig
cp commoncpp/tcp.cpp commoncpp/tcp.cpp.orig
cp inc/ucommon/generics.h inc/ucommon/generics.h.orig
cp inc/ucommon/temporary.h inc/ucommon/temporary.h.orig
fi

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/ucommon.patch ]]; then
    patch -u -p0 < ../patch/ucommon.patch
    echo ""
fi

if false; then
{
diff -u openssl/digest.cpp.orig openssl/digest.cpp
diff -u openssl/random.cpp.orig openssl/random.cpp
diff -u openssl/cipher.cpp.orig openssl/cipher.cpp
diff -u openssl/hmac.cpp.orig openssl/hmac.cpp
diff -u commoncpp/tcp.cpp.orig commoncpp/tcp.cpp
diff -u inc/ucommon/generics.h.orig inc/ucommon/generics.h
diff -u inc/ucommon/temporary.h.orig inc/ucommon/temporary.h
} > ../patch/ucommon.patch
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
    --with-sslstack=openssl

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure ucommon"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build ucommon"
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
    echo "**********************"
    echo "Failed to test ucommon"
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

    ARTIFACTS=("$UCOMMON_TAR" "$UCOMMON_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ucommon.sh 2>&1 | tee build-ucommon.log
    if [[ -e build-ucommon.log ]]; then
        rm -f build-ucommon.log
    fi
fi

exit 0
