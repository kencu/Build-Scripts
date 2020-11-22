#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds HFS+ Tools from sources.

HFSPLUSTOOLS_DIR=hsfplustools-master
PKG_NAME=hsfplustools

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

INSTX_JOBS="${INSTX_JOBS:-2}"

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
echo "============== HFS+ Tools =============="
echo "========================================"

rm -rf "$HFSPLUSTOOLS_DIR" 2>/dev/null

echo ""
echo "**********************"
echo "Cloning package"
echo "**********************"

if ! git clone --depth=3 https://github.com/miniupnp/hfsplustools.git "$HFSPLUSTOOLS_DIR";
then
    echo "Failed to checkout HFS+ Tools"
    exit 1
fi

cd "$HFSPLUSTOOLS_DIR"
git checkout master &>/dev/null

echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
export CPPFLAGS=$(echo "${INSTX_CPPFLAGS[*]}" | sed 's/\$/\$\$/g')
export ASFLAGS=$(echo "${INSTX_ASFLAGS[*]}" | sed 's/\$/\$\$/g')
export CFLAGS=$(echo "${INSTX_CFLAGS[*]}" | sed 's/\$/\$\$/g')
export CXXFLAGS=$(echo "${INSTX_CXXFLAGS[*]}" | sed 's/\$/\$\$/g')
export LDFLAGS=$(echo "${INSTX_LDFLAGS[*]}" | sed 's/\$/\$\$/g')
export LIBS="${INSTX_LIBS[*]}"

export PREFIX="$INSTX_PREFIX"
export LIBDIR="$INSTX_LIBDIR"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build HFS+ Tools"
    exit 1
fi

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# Man, Valgirnd is awful when it comes to trying to build self tests.
# MAKE_FLAGS=("check" "-k" "V=1")
# if ! "${MAKE}" "${MAKE_FLAGS[@]}"
# then
#    echo "Failed to test HFS+ Tools"
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
if true;
then
    ARTIFACTS=("$HFSPLUSTOOLS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
