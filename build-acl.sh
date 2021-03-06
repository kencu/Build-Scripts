#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds libacl from sources.

ACL_VER=2.2.53
ACL_TAR=acl-${ACL_VER}.tar.gz
ACL_DIR=acl-${ACL_VER}
PKG_NAME=acl

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

if ! ./build-iconv-gettext.sh
then
    echo echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-attr.sh
then
    echo echo "Failed to build libattr"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ libacl ================"
echo "========================================"

echo ""
echo "**************************"
echo "Downloading package"
echo "**************************"

if ! "$WGET" -q -O "$ACL_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://download.savannah.nongnu.org/releases/acl/$ACL_TAR"
then
    echo "Failed to download libacl"
    exit 1
fi

rm -rf "$ACL_DIR" &>/dev/null
gzip -d < "$ACL_TAR" | tar xf -
cd "$ACL_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/acl.patch ]]; then
    patch -u -p0 < ../patch/acl.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**************************"
echo "Configuring package"
echo "**************************"

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
    --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]
then
    echo "**************************"
    echo "Failed to configure libacl"
    echo "**************************"

    bash ../collect-logs.sh
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**************************"
echo "Building package"
echo "**************************"

MAKE_FLAGS=("MAKEINFO=true" "-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**************************"
    echo "Failed to build libacl"
    echo "**************************"

    bash ../collect-logs.sh
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**************************"
echo "Testing package"
echo "**************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**************************"
    echo "Failed to test libacl"
    echo "**************************"

    bash ../collect-logs.sh
    exit 1
fi

echo "**************************"
echo "Installing package"
echo "**************************"

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
    ARTIFACTS=("$ACL_TAR" "$ACL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
