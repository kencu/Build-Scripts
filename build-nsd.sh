#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds NSD from sources.

NSD_VER=4.3.3
NSD_TAR=nsd-${NSD_VER}.tar.gz
NSD_DIR=nsd-${NSD_VER}

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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= NSD =================="
echo "========================================"

echo ""
echo "***********************"
echo "Downloading package"
echo "***********************"

if ! "$WGET" -q -O "$NSD_TAR" --ca-certificate="$IDENTRUST_ROOT" \
     "https://www.nlnetlabs.nl/downloads/nsd/$NSD_TAR"
then
    echo "Failed to download NSD"
    exit 1
fi

rm -rf "$NSD_DIR" &>/dev/null
gzip -d < "$NSD_TAR" | tar xf -
cd "$NSD_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/nsd.patch ]]; then
    patch -u -p0 < ../patch/nsd.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "***********************"
echo "Configuring package"
echo "***********************"

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
    --libdir="$INSTX_LIBDIR" \
    --with-ssl="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]
then
    echo "***********************"
    echo "Failed to configure NSD"
    echo "***********************"

    bash ../collect-logs.sh
    exit 1
fi

# Fix config.h. We define NDEBUG in CPPFLAGS
sed 's/#define NDEBUG \/\*\*\///g' config.h > config.h.fixed
mv config.h.fixed config.h

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "***********************"
echo "Building package"
echo "***********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***********************"
    echo "Failed to build NSD"
    echo "***********************"

    bash ../collect-logs.sh
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "***********************"
echo "Testing package"
echo "***********************"

MAKE_FLAGS=("test" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***********************"
    echo "Failed to test NSD"
    echo "***********************"

    bash ../collect-logs.sh
    exit 1
fi

echo "***********************"
echo "Installing package"
echo "***********************"

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
if true;
then
    ARTIFACTS=("$NSD_TAR" "$NSD_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
