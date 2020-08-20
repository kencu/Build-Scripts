#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds APG from sources. APG is treated
# like a library rather then a program to avoid rebuilding
# it in other recipes like Curl and Wget.

APG_TAR=v2.2.3.tar.gz
APG_DIR=apg-2.2.3
PKG_NAME=apg

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
echo "================= APG ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$APG_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/jabenninghoff/apg/archive/$APG_TAR"
then
    echo "Failed to download APG"
    exit 1
fi

rm -rf "$APG_DIR" &>/dev/null
gzip -d < "$APG_TAR" | tar xf -
cd "$APG_DIR" || exit 1

#cp Makefile Makefile.orig
#cp apg.c apg.c.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/apg.patch ]]; then
    patch -u -p0 < ../patch/apg.patch
    echo ""
fi

echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "${INSTX_CPPFLAGS[*]}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS[*]}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS[*]}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS[*]}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LIBS[*]}"

if [[ "$IS_LINUX" -ne 0 ]]; then
    LIBS="-lcrypt ${LIBS}"
fi

MAKE_FLAGS=("standalone" "-j" "$INSTX_JOBS")
if ! CPPFLAGS="${CPPFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build APG"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

echo "**********************"
echo "Package not tested"
echo "**********************"

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "APG_PREFIX=$INSTX_PREFIX")
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

    ARTIFACTS=("$APG_TAR" "$APG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-apg.sh 2>&1 | tee build-apg.log
    if [[ -e build-apg.log ]]; then
        rm -f build-apg.log
    fi
fi

exit 0
