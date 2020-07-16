#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Unistring from sources.

UNISTR_TAR=libunistring-0.9.10.tar.gz
UNISTR_DIR=libunistring-0.9.10
PKG_NAME=unistring

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

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

echo
echo "********** Unistring **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$UNISTR_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/libunistring/$UNISTR_TAR"
then
    echo "Failed to download Unistring"
    exit 1
fi

rm -rf "$UNISTR_DIR" &>/dev/null
gzip -d < "$UNISTR_TAR" | tar xf -
cd "$UNISTR_DIR"

if [[ -e ../patch/unistring.patch ]]; then
    patch -u -p0 < ../patch/unistring.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# https://bugs.launchpad.net/ubuntu/+source/binutils/+bug/1340250
if [[ -n "$OPT_NO_AS_NEEDED" ]]; then
    INSTX_LIBS[${#INSTX_LIBS[@]}]="$OPT_NO_AS_NEEDED"
fi

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
    --enable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Unistring"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "************************"
echo "Building package"
echo "************************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Unistring"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "************************"
echo "Testing package"
echo "************************"

# Unistring fails one self test on older systems, like Fedora 1
# and Ubuntu 4. Allow the failure but print the result.
MAKE_FLAGS=("check" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "************************"
    echo "Failed to test Unistring"
    echo "************************"
    # exit 1
fi

echo "************************"
echo "Installing package"
echo "************************"

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
if true; then

    ARTIFACTS=("$UNISTR_TAR" "$UNISTR_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-unistring.sh 2>&1 | tee build-unistring.log
    if [[ -e build-unistring.log ]]; then
        rm -f build-unistring.log
    fi
fi

exit 0
