#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds CMake and its dependencies from sources.

CMAKE_VER="3.14.3"
CMAKE_TAR=cmake-"$CMAKE_VER".tar.gz
CMAKE_DIR=cmake-"$CMAKE_VER"

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

if ! ./setup-cacerts.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

echo
echo "********** CMake **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$CMAKE_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/$CMAKE_TAR"
then
    echo "Failed to download CMake"
    exit 1
fi

rm -rf "$CMAKE_DIR" &>/dev/null
gzip -d < "$CMAKE_TAR" | tar xf -

cd "$CMAKE_DIR"

echo "**********************"
echo "Bootstrapping package"
echo "**********************"

# This is the CMake build command per https://cmake.org/install/
if ! ./bootstrap
then
    echo "Failed to bootstrap CMake"
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
    echo "Failed to build CMake"
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
   echo "Failed to test CMake"
   exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ ! ("$SUDO_PASSWORD_SET" != "yes") ]]; then
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

    ARTIFACTS=("$CMAKE_TAR" "$CMAKE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-cmake.sh 2>&1 | tee build-cmake.log
    if [[ -e build-cmake.log ]]; then
        rm -f build-cmake.log
    fi
fi

exit 0
