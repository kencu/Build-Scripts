#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds PSL from sources.

PSL_TAR=libpsl-0.21.0.tar.gz
PSL_DIR=libpsl-0.21.0
PKG_NAME=libpsl

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

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    exit 1
fi

###############################################################################

echo
echo "********** libpsl **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$PSL_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/rockdaboot/libpsl/releases/download/$PSL_DIR/$PSL_TAR"
then
    echo "Failed to download libpsl"
    exit 1
fi

rm -rf "$PSL_DIR" &>/dev/null
gzip -d < "$PSL_TAR" | tar xf -
cd "$PSL_DIR"

if [[ -e ../patch/libpsl.patch ]]; then
    patch -u -p0 < ../patch/libpsl.patch
    echo ""
fi

# libpsl needs a new release
if ! "$WGET" -q -O "tests/test-is-public-builtin.c" --ca-certificate="$CA_ZOO" \
     "https://raw.githubusercontent.com/rockdaboot/libpsl/master/tests/test-is-public-builtin.c"
then
    echo "Failed to patch test-is-public-builtin.c"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# Solaris is a tab bit stricter than libc
if [[ "$IS_SOLARIS" -eq 1 ]]; then
    # Don't use CPPFLAGS. _XOPEN_SOURCE will cross-pollinate into CXXFLAGS.
    INSTX_CFLAGS+=("-D_XOPEN_SOURCE=600 -std=gnu99")
    # INSTX_CXXFLAGS+=("-std=c++03")
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --enable-runtime=libidn2 \
    --enable-builtin=libidn2 \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure libpsl"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Updating package"
echo "**********************"

# Update the PSL data file
echo "Updating Public Suffix List (PSL) data file"
mkdir -p list

# Per the comments at publicsuffix.org/:
#   Please pull this list from, and only from
#   https://publicsuffix.org/list/public_suffix_list.dat,
#   rather than any other VCS sites. Pulling from any other
#   URL is not guaranteed to be supported.
if ! "$WGET" -q -O "list/public_suffix_list.dat" --ca-certificate="$CA_ZOO" \
     "https://publicsuffix.org/list/public_suffix_list.dat"
then
    echo "Failed to update Public Suffix List (PSL)"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build libpsl"
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
	echo "Failed to test libpsl"
	echo ""
	echo "If you have existing libpsl libraries at $INSTX_LIBDIR"
	echo "then you should manually delete them and run this script again."
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

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PSL_TAR" "$PSL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-libpsl.sh 2>&1 | tee build-libpsl.log
    if [[ -e build-libpsl.log ]]; then
        rm -f build-libpsl.log
    fi
fi

exit 0
