#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenVPN and its dependencies from sources.

TUNTAP_TAR=v1.3.3.tar.gz
TUNTAP_DIR=tuntap-1.3.3

OPENVPN_TAR=openvpn-2.4.8.tar.gz
OPENVPN_DIR=openvpn-2.4.8

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:-2}"

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

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if [[ "$IS_SOLARIS" -ne 0 ]]; then

echo
echo "********** Solaris TUN/TAP Driver **********"
echo

echo "**********************"
echo "Downloading TUN/TAP"
echo "**********************"

if ! "$WGET" -q -O "$TUNTAP_TAR" --ca-certificate="$DIGICERT_ROOT" \
     "https://github.com/kaizawa/tuntap/archive/$TUNTAP_TAR"
then
    echo "Failed to download TUN/TAP driver"
    exit 1
fi

rm -rf "$TUNTAP_DIR" &>/dev/null
gzip -d < "$TUNTAP_TAR" | tar xf -
cd "$TUNTAP_DIR"

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
    --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure TUN/TAP driver"
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
    echo "Failed to build TUN/TAP driver"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

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

fi  # Solaris

###############################################################################

echo
echo "********** OpenVPN **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$OPENVPN_TAR" --ca-certificate="$ADDTRUST_ROOT" \
     "https://swupdate.openvpn.org/community/releases/$OPENVPN_TAR"
then
    echo "Failed to download OpenVPN"
    exit 1
fi

rm -rf "$OPENVPN_DIR" &>/dev/null
gzip -d < "$OPENVPN_TAR" | tar xf -
cd "$OPENVPN_DIR"

if [[ -e ../patch/openvpn.patch ]]; then
    patch -u -p0 < ../patch/openvpn.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" LIBS="${INSTX_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --with-crypto-library=openssl --disable-lzo --disable-lz4 --disable-plugin-auth-pam

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure OpenVPN"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenVPN"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenVPN"
    exit 1
fi

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

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$TUNTAP_TAR" "$TUNTAP_DIR" "$OPENVPN_TAR" "$OPENVPN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openvpn.sh 2>&1 | tee build-openvpn.log
    if [[ -e build-openvpn.log ]]; then
        rm -f build-openvpn.log
    fi
fi

exit 0
