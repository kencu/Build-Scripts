#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds pkg-config from sources.

PKGCONFIG_TAR=pkg-config-0.29.2.tar.gz
PKGCONFIG_DIR=pkg-config-0.29.2

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

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
echo "********** pkg-config **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if [[ -n $(command -v "$WGET" 2>/dev/null) ]]
then
    if ! "$WGET" -q -O "$PKGCONFIG_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
         "https://pkg-config.freedesktop.org/releases/$PKGCONFIG_TAR"
    then
        echo "Failed to download pkg-config"
        exit 1
    fi
else
    if ! curl -s -o "$PKGCONFIG_TAR" --cacert "$LETS_ENCRYPT_ROOT" \
         "https://pkg-config.freedesktop.org/releases/$PKGCONFIG_TAR"
    then
        echo "Failed to download pkg-config"
        exit 1
    fi
fi

rm -rf "$PKGCONFIG_DIR" &>/dev/null
gzip -d < "$PKGCONFIG_TAR" | tar xf -
cd "$PKGCONFIG_DIR"

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
    --with-internal-glib

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure pkg-config"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "MAKEINFO=true")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build pkg-config"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pkgconfig.sh .
./fix-pkgconfig.sh

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
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
