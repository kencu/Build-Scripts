#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Gnulib from sources.

# Gnulib is distributed as source from GitHub. No packages
# are available for download. Also see
# https://www.linux.com/news/using-gnulib-improve-software-portability

# Testing Gnulib is detailed at https://lists.gnu.org/archive/html/bug-gnulib/2017-05/msg00118.html.

GNULIB_DIR=gnulib
GNULIB_TEST_DIR=gnulib_test
PKG_NAME=gnulib

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
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
echo "********** Gnulib **********"
echo

# Cleanup old artifacts in case of early out
rm -rf "$GNULIB_DIR" "$GNULIB_TEST_DIR" 2>/dev/null

echo "**********************"
echo "Cloning package"
echo "**********************"

if ! git clone --depth=3 git://git.savannah.gnu.org/gnulib.git "$GNULIB_DIR"
then
    echo "Failed to clone Gnulib"
    exit 1
fi

cd "$GNULIB_DIR" || exit 1

echo "Copying Gnulib sources"
if ! ./gnulib-tool --create-testdir --dir=../"$GNULIB_TEST_DIR" --avoid=gettext --single-configure --without-privileged-tests;
then
    echo "Failed to copy Gnulib sources"
    exit 1
fi

cd "$CURR_DIR" || exit 1
cd "$GNULIB_TEST_DIR" || exit 1

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
    --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Gnulib"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Gnulib"
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
    echo "**********************"
    echo "Failed to test Gnulib"
    echo "**********************"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Gnulib"
    exit 1
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GNULIB_DIR" "$GNULIB_TEST_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-Gnulib.sh 2>&1 | tee build-gnulib.log
    if [[ -e build-gnulib.log ]]; then
        rm -f build-gnulib.log
    fi
fi

exit 0
