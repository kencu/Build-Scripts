#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Valgrind from sources.

VALGRIND_DIR=valgrind-master
PKG_NAME=valgrind

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
if [[ "$SUDO_PASSWORD_DONE" != "yes" ]]; then
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

echo ""
echo "========================================"
echo "=============== Valgrind ==============="
echo "========================================"

rm -rf "$VALGRIND_DIR" 2>/dev/null

echo ""
echo "**********************"
echo "Cloning package"
echo "**********************"

if ! git clone --depth=3 git://sourceware.org/git/valgrind.git "$VALGRIND_DIR";
then
    echo "Failed to checkout Valgrind"
    exit 1
fi

cd "$VALGRIND_DIR"

if ! ./autogen.sh
then
    echo "Failed to generate Valgrind build files"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="-g2 -O3" \
    ASFLAGS="" \
    CFLAGS="-g2 -O3" \
    CXXFLAGS="-g2 -O3" \
    LDFLAGS="" \
    LIBS="" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Valgrind"
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
    echo "Failed to build Valgrind"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# Man, Valgirnd is awful when it comes to trying to build self tests.
# MAKE_FLAGS=("check" "V=1")
# if ! "${MAKE}" "${MAKE_FLAGS[@]}"
# then
#    echo "Failed to test Valgrind"
#    exit 1
# fi

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

    ARTIFACTS=("$VALGRIND_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-valgrind.sh 2>&1 | tee build-valgrind.log
    if [[ -e build-valgrind.log ]]; then
        rm -f build-valgrind.log
    fi
fi

exit 0
