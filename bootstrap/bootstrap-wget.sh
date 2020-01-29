#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources. It
# is useful for bootstrapping a full Wget build.

# Binaries
WGET_TAR=wget-1.20.3.tar.gz
UNISTR_TAR=libunistring-0.9.10.tar.gz
SSL_TAR=openssl-1.0.2u.tar.gz

# Directories
BOOTSTRAP_DIR=$(pwd)
WGET_DIR=wget-1.20.3
UNISTR_DIR=libunistring-0.9.10
SSL_DIR=openssl-1.0.2u

# Install location
PREFIX="$HOME/bootstrap"
LIBDIR="$PREFIX/lib"

###############################################################################

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR" || exit 1
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

############################## Misc ##############################

: "${CC:=cc}"
if $CC $CFLAGS bitness.c -o /dev/null &>/dev/null; then
    INSTX_BITNESS=64
else
    INSTX_BITNESS=32
fi

HAVE_OPT=0
if $CC $CFLAGS comptest.c -ldl -o /dev/null &>/dev/null; then
    HAVE_OPT=1
fi

if [[ "$HAVE_OPT" -eq 1 ]]; then
   LDL_OPT=-ldl
fi

IS_DARWIN=$(echo -n "$(uname -s 2>&1)" | grep -i -c 'darwin')
IS_LINUX=$(echo -n "$(uname -s 2>&1)" | grep -i -c 'linux')
IS_AMD64=$(echo -n "$(uname -m 2>&1)" | grep -i -c -E 'x86_64|amd64')
#IS_SOLARIS=$(echo -n "$(uname -s 2>&1)" | grep -i -c 'sunos')

# OpenSSL PowerMac and friends
if [[ "$IS_DARWIN" -ne "0" ]]; then
    DARWIN_CFLAGS="-force_cpusubtype_ALL"
fi

# DH is 2x to 4x faster with ec_nistp_64_gcc_128, but it is
# only available on x64 machines with uint128 available.
INT128_OPT=$("$CC" -dM -E - </dev/null | grep -i -c "__SIZEOF_INT128__")

if [[ "$IS_AMD64" -ne "0" && "$INT128_OPT" -eq 1 ]]; then
    AMD64_OPT="enable-ec_nistp_64_gcc_128"
fi

############################## CA Certs ##############################

echo
echo "*************************************************"
echo "Configure CA certs"
echo "*************************************************"
echo

# Copy our copy of cacerts to bootstrap
mkdir -p "$PREFIX/cacert/"
cp cacert.pem "$PREFIX/cacert/cacert.pem"

echo "Copy cacert.pem $PREFIX/cacert/cacert.pem"
echo "Done."

############################## OpenSSL ##############################

echo
echo "*************************************************"
echo "Building OpenSSL"
echo "*************************************************"
echo

rm -rf "$SSL_DIR" &>/dev/null
gzip -d < "$SSL_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$SSL_DIR" || exit 1

    KERNEL_BITS="$INSTX_BITNESS" \
./config \
    --prefix="$PREFIX" \
    --openssldir="$PREFIX" \
    "$AMD64_OPT" -fPIC "$DARWIN_CFLAGS" \
    no-ssl2 no-ssl3 no-comp no-zlib no-zlib-dynamic no-asm no-threads no-shared no-dso no-engine

# This will need to be fixed for BSDs and PowerMac
if ! make depend; then
    echo "Failed to update OpenSSL dependencies"
    exit 1
fi

if ! make -j "$INSTX_JOBS"; then
    echo "Failed to build OpenSSL"
    exit 1
fi

if ! make install_sw; then
    echo "Failed to install OpenSSL"
    exit 1
fi

sed 's|$dir/certs|$dir/cacert|g' "$PREFIX/openssl.cnf" > "$PREFIX/openssl.cnf.new"
mv "$PREFIX/openssl.cnf.new" "$PREFIX/openssl.cnf"

############################ OpenSSL libs #############################

# OpenSSL does not honor no-dso. Needed by Unistring and Wget.
OPENSSL_LIBS="$LIBDIR/libssl.a $LIBDIR/libcrypto.a $LDL_OPT"

############################## Unistring ##############################

cd "$BOOTSTRAP_DIR" || exit 1

echo
echo "*************************************************"
echo "Building Unistring"
echo "*************************************************"
echo

rm -rf "$UNISTR_DIR" &>/dev/null
gzip -d < "$UNISTR_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$UNISTR_DIR" || exit 1

    CFLAGS="$CFLAGS $DARWIN_CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    PKG_CONFIG_PATH="$LIBDIR/pkgconfig/" \
    OPENSSL_LIBS="$OPENSSL_LIBS" \
./configure \
    --prefix="$PREFIX" \
    --disable-shared

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Unistring"
    exit 1
fi

if ! make -j "$INSTX_JOBS" V=1; then
    echo "Failed to build Unistring"
    exit 1
fi

if ! make install; then
    echo "Failed to install Unistring"
    exit 1
fi

############################## Wget ##############################

cd "$BOOTSTRAP_DIR" || exit 1

echo
echo "*************************************************"
echo "Building Wget"
echo "*************************************************"
echo

rm -rf "$WGET_DIR" &>/dev/null
gzip -d < "$WGET_TAR" | tar xf -
cd "$BOOTSTRAP_DIR/$WGET_DIR" || exit 1

# Install recipe does not overwrite a config, if present.
if [[ -f "$PREFIX/etc/wgetrc" ]]; then
    rm "$PREFIX/etc/wgetrc"
fi

    CFLAGS="$CFLAGS $DARWIN_CFLAGS" \
    LDFLAGS="$LDFLAGS" \
    PKG_CONFIG_PATH="$LIBDIR/pkgconfig/" \
    OPENSSL_LIBS="$OPENSSL_LIBS" \
./configure \
    --sysconfdir="$PREFIX/etc" \
    --prefix="$PREFIX" \
    --with-ssl=openssl \
    --without-zlib \
    --without-libpsl \
    --without-libuuid \
    --without-libidn \
    --without-cares \
    --disable-pcre \
    --disable-pcre2 \
    --disable-nls \
    --disable-iri

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Wget"
    exit 1
fi

# Fix makefiles. No shared objects.
for file in $(find . -iname Makefile)
do
    sed "s|-lssl|$LIBDIR/libssl.a|g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    sed "s|-lcrypto|$LIBDIR/libcrypto.a|g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    sed "s|-lunistring|$LIBDIR/libunistring.a|g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

if ! make -j "$INSTX_JOBS" V=1; then
    echo "Failed to build Wget"
    exit 1
fi

if ! make install; then
    echo "Failed to install Wget"
    exit 1
fi

# Wget configuration file
{
    echo ""
    echo "# cacert.pem location"
    echo "ca_directory = $PREFIX/cacert/"
    echo "ca_certificate = $PREFIX/cacert/cacert.pem"
    echo ""
} > "$PREFIX/etc/wgetrc"

# Cleanup
if true; then
    cd "$CURR_DIR" || exit 1
    rm -rf "$WGET_DIR"
    rm -rf "$UNISTR_DIR"
    rm -rf "$SSL_DIR"
fi

exit 0
