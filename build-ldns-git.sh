#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds LDNS from sources.

LDNS_DIR=ldns-master
LDNS_TAG=release-1.7.0
PKG_NAME=ldns

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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-unbound.sh
then
    echo "Failed to build Unbound"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= LDNS ================="
echo "========================================"

echo ""
echo "**********************"
echo "Cloning package"
echo "**********************"

rm -rf "$LDNS_DIR" &>/dev/null

if ! git clone https://github.com/NLnetLabs/ldns.git "$LDNS_DIR"
then
    echo "Failed to clone LDNS"
    exit 1
fi

cd "$LDNS_DIR"
git checkout "$LDNS_TAG" &>/dev/null

if [[ "$IS_OLD_DARWIN" -ne 0 ]]; then
    if [[ -e ../patch/ldns-darwin.patch ]]; then
        patch -u -p0 < ../patch/ldns-darwin.patch
        echo ""
    fi
fi

sed '11iAM_INIT_AUTOMAKE' configure.ac > configure.ac.fixed
mv configure.ac.fixed configure.ac

mkdir -p m4/
automake --add-missing
autoreconf --force --install

if [[ ! -f ./configure ]]
then
    echo "Failed to autoreconf LDNS"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

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
    --with-ssl="$INSTX_PREFIX" \
    --with-ca-file="$OPT_UNBOUND_ICANN_FILE" \
    --with-ca-path="$OPT_UNBOUND_ICANN_PATH" \
    --with-trust-anchor="$OPT_UNBOUND_ROOTKEY_FILE" \
    --disable-dane-ta-usage

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure LDNS"
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
    echo "Failed to build LDNS"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

echo
echo "Unable to test ldns"
echo

# 'make test' fails. The tarball is missing the test framework.
# Master is missing the source code for tpkg, and the test script
# accesses internal company URLs.
# https://github.com/NLnetLabs/ldns/issues/8
# https://github.com/NLnetLabs/ldns/issues/13
#MAKE_FLAGS=("test")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test LDNS"
#    exit 1
#fi

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

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$LDNS_TAR" "$LDNS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ldns.sh 2>&1 | tee build-ldns.log
    if [[ -e build-ldns.log ]]; then
        rm -f build-ldns.log
    fi
fi

exit 0
