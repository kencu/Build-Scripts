#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GNU Diffutils from sources.

DIFFUTILS_XZ=diffutils-3.7.tar.xz
DIFFUTILS_TAR=diffutils-3.7.tar
DIFFUTILS_DIR=diffutils-3.7

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
echo "********** GNU Diffutils **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$DIFFUTILS_XZ" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/diffutils/$DIFFUTILS_XZ"
then
    echo "Failed to download GNU Diffutils"
    exit 1
fi

rm -rf "$DIFFUTILS_TAR" "$DIFFUTILS_DIR" &>/dev/null
unxz "$DIFFUTILS_XZ" && tar -xf "$DIFFUTILS_TAR"
cd "$DIFFUTILS_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GNU Diffutils"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GNU Diffutils"
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
    echo "Failed to test GNU Diffutils"
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

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$DIFFUTILS_XZ" "$DIFFUTILS_TAR" "$DIFFUTILS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-diffutils.sh 2>&1 | tee build-diffutils.log
    if [[ -e build-diffutils.log ]]; then
        rm -f build-diffutils.log
    fi
fi

exit 0
