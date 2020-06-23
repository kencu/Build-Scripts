#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds cURL from sources.

CURL_TAR=curl-7.70.0.tar.gz
CURL_DIR=curl-7.70.0
PKG_NAME=curl

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
    echo "Failed to install CA certs"
    exit 1
fi

###############################################################################

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-idn2.sh
then
    echo "Failed to build IDN2"
    exit 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

# Needs real C++11 support
if [[ "$HAS_CXX11" -eq 1 ]]
then
    if ! ./build-nghttp2.sh
    then
        echo "Failed to build NGHTTP2"
        exit 1
    fi
fi

###############################################################################

if ! ./build-openldap.sh
then
    echo "Failed to build OpenLDAP"
    exit 1
fi

###############################################################################

echo
echo "********** cURL **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$CURL_TAR" --ca-certificate="$CA_ZOO" \
     "https://curl.haxx.se/download/$CURL_TAR"
then
    echo "Failed to download cURL"
    exit 1
fi

rm -rf "$CURL_DIR" &>/dev/null
gzip -d < "$CURL_TAR" | tar xf -
cd "$CURL_DIR" || exit 1

if [[ -e ../patch/curl.patch ]]; then
    patch -u -p0 < ../patch/curl.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--enable-optimize")
CONFIG_OPTS+=("--enable-symbol-hiding")
CONFIG_OPTS+=("--enable-http")
CONFIG_OPTS+=("--enable-ftp")
CONFIG_OPTS+=("--enable-file")
CONFIG_OPTS+=("--enable-ldap")
CONFIG_OPTS+=("--enable-ldaps")
CONFIG_OPTS+=("--enable-rtsp")
CONFIG_OPTS+=("--enable-proxy")
CONFIG_OPTS+=("--enable-dict")
CONFIG_OPTS+=("--enable-telnet")
CONFIG_OPTS+=("--enable-tftp")
CONFIG_OPTS+=("--enable-pop3")
CONFIG_OPTS+=("--enable-imap")
CONFIG_OPTS+=("--enable-smb")
CONFIG_OPTS+=("--enable-smtp")
CONFIG_OPTS+=("--enable-gopher")
CONFIG_OPTS+=("--enable-cookies")
CONFIG_OPTS+=("--enable-ipv6")
CONFIG_OPTS+=("--with-zlib=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-ssl=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-libidn2=$INSTX_PREFIX")
CONFIG_OPTS+=("--without-gnutls")
CONFIG_OPTS+=("--without-polarssl")
CONFIG_OPTS+=("--without-mbedtls")
CONFIG_OPTS+=("--without-cyassl")
CONFIG_OPTS+=("--without-nss")
CONFIG_OPTS+=("--without-libssh2")
CONFIG_OPTS+=("--with-ca-bundle=$SH_CACERT_FILE")

if [[ "$HAS_CXX11" -eq 1 ]]; then
    CONFIG_OPTS+=("--with-nghttp2")
else
    CONFIG_OPTS+=("--without-nghttp2")
fi

# OpenSSL 1.1.1e does not have RAND_egd, but curl lacks --without-egd
# We also want to disable the SSLv2 code paths. Hack it by providing
# ac_cv_func_RAND_egd=no and ac_cv_func_SSLv2_client_method=no.

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    ac_cv_func_RAND_egd=no \
    ac_cv_func_SSLv2_client_method=no \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure cURL"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build cURL"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# Disable Valgrind with "TFLAGS=-n". Too many findings due
# to -march=native. We also want the sanitizers since others
# are doing the Valgrind testing.
MAKE_FLAGS=("test" "TFLAGS=-n" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
#    echo "Failed to test cURL"
#    exit 1
    :
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

    ARTIFACTS=("$CURL_TAR" "$CURL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-curl.sh 2>&1 | tee build-curl.log
    if [[ -e build-curl.log ]]; then
        rm -f build-curl.log
    fi
fi

exit 0
