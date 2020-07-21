#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Hiredis from sources.

HIREDIS_TAR=v0.14.0.tar.gz
HIREDIS_DIR=hiredis-0.14.0
PKG_NAME=hidredis

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

if ! ./build-libexpat.sh
then
    echo "Failed to build Expat"
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
echo "********** Hiredis **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$HIREDIS_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/redis/hiredis/archive/$HIREDIS_TAR"
then
    echo "Failed to download Hiredis"
    exit 1
fi

rm -rf "$HIREDIS_DIR" &>/dev/null
gzip -d < "$HIREDIS_TAR" | tar xf -
cd "$HIREDIS_DIR"

if [[ -e ../patch/hiredis.patch ]]; then
    patch -u -p0 < ../patch/hiredis.patch
    echo ""
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

# Awful Solaris 64-bit hack. Use -G for SunC, and -shared for GCC
if [[ "$IS_SOLARIS" -ne 0 && "$IS_SUNC" -eq 0 ]]; then
    sed 's/ -G / -shared /g' Makefile > Makefile.fixed
    mv Makefile.fixed Makefile; chmod +x Makefile
fi

echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}"
CPPFLAGS=$(echo "${INSTX_CPPFLAGS[*]}" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "${INSTX_ASFLAGS[*]}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS[*]}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS[*]}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS[*]}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LIBS[*]}"

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "Makefile")
MAKE_FLAGS+=("-j" "$INSTX_JOBS")
MAKE_FLAGS+=("PREFIX=$INSTX_PREFIX")
MAKE_FLAGS+=("LIBDIR=$INSTX_LIBDIR")
MAKE_FLAGS+=("PKGLIBDIR=${PKG_CONFIG_PATH}")

    CPPFLAGS="${CPPFLAGS}" \
    ASFLAGS="${ASFLAGS}" \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CXXFLAGS}" \
    LDFLAGS="${LDFLAGS}" \
    LIBS="${LIBS}" \
"${MAKE}" "${MAKE_FLAGS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to build Hiredis"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

echo
echo "Unable to test Hiredis"
echo

# Need redis-server
#MAKE_FLAGS=("check" "V=1")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Hidredis"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
MAKE_FLAGS+=("PREFIX=$INSTX_PREFIX")
MAKE_FLAGS+=("LIBDIR=$INSTX_LIBDIR")
MAKE_FLAGS+=("PKGLIBDIR=${INSTX_PKGCONFIG[*]}")

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
if true; then

    ARTIFACTS=("$HIREDIS_TAR" "$HIREDIS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-hidredis.sh 2>&1 | tee build-hidredis.log
    if [[ -e build-hidredis.log ]]; then
        rm -f build-hidredis.log
    fi
fi

exit 0
