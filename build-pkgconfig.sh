#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Autotools from sources. A separate
# script is available for Libtool for brave souls.

# Trying to update Autotools may be more trouble than it is
# worth. If the upgrade goes bad, then you can uninstall
# it with the script clean-pkgconfig.sh

PKGCONFIG_TAR=pkg-config-0.29.2.tar.gz
PKGCONFIG_DIR=pkg-config-0.29.2

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# pkg-config is special
export INSTX_DISABLE_PKGCONFIG_CHECK=1

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

echo
echo "********** pkg-config **********"
echo

if [[ -n $(command -v "$WGET" 2>/dev/null) ]]
then
    if ! "$WGET" -O "$PKGCONFIG_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
         "https://pkg-config.freedesktop.org/releases/$PKGCONFIG_TAR"
    then
        echo "Failed to download pkg-config"
        exit 1
    fi
else
    if ! curl -L -o "$PKGCONFIG_TAR" --cacert "$LETS_ENCRYPT_ROOT" \
         "https://pkg-config.freedesktop.org/releases/$PKGCONFIG_TAR"
    then
        echo "Failed to download pkg-config"
        exit 1
    fi
fi

rm -rf "$PKGCONFIG_DIR" &>/dev/null
gzip -d < "$PKGCONFIG_TAR" | tar xf -
cd "$PKGCONFIG_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

CONFIG_OPTS=()
CONFIG_OPTS+=("--build=$AUTOCONF_BUILD")
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")

if [[ "$IS_DARWIN" -ne 0 ]]; then
    CONFIG_OPTS=(--with-internal-glib)
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure pkg-config"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "MAKEINFO=true")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build pkg-config"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Update program cache
hash -r &>/dev/null

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$PKGCONFIG_TAR" "$PKGCONFIG_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-pkgconfig.sh 2>&1 | tee build-pkgconfig.log
    if [[ -e build-pkgconfig.log ]]; then
        rm -f build-pkgconfig.log
    fi
fi

exit 0
