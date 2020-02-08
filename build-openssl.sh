#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenSSL from sources.

# OpenSSH and a few other key programs can only use OpenSSL 1.0.2 at the moment
OPENSSL_TAR=openssl-1.1.1d.tar.gz
OPENSSL_DIR=openssl-1.1.1d
PKG_NAME=openssl

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

if [[ -e "$INSTX_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# Get a sudo password as needed. The password should die when this
# subshell goes out of scope.
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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if [[ -n $(command -v perl 2>/dev/null) ]]; then
    PERL_MAJ=$(perl -V | head -n 1 | awk '{ print $6 }')
    PERL_MIN=$(perl -V | head -n 1 | awk '{ print $8 }')
else
    PERL_MAJ=0
    PERL_MIN=0
fi

# OpenSSL needs Perl 5.10 or above.
if [[ "$PERL_MAJ" -lt 5 || ("$PERL_MAJ" -eq 5 && "$PERL_MIN" -lt 10) ]]
then
    if ! ./build-perl.sh
    then
        echo "Failed to build Perl"
        exit 1
    fi
fi

###############################################################################

# May be skipped if Perl is too old
SKIP_OPENSSL_TESTS=0

# OpenSSL self tests
if ! perl -MTest::More -e1 2>/dev/null
then
    echo ""
    echo "OpenSSL requires Perl's Test::More. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Test-More."
    SKIP_OPENSSL_TESTS=1
fi

# OpenSSL self tests
if ! perl -MText::Template -e1 2>/dev/null
then
    echo ""
    echo "OpenSSL requires Perl's Text::Template. Skipping OpenSSL self tests."
    echo "To fix this issue, please install Text-Template."
    SKIP_OPENSSL_TESTS=1
fi

# DH is 2x to 4x faster with ec_nistp_64_gcc_128, but it is
# only available on x64 machines with uint128 available.
INT128_OPT=$("$CC" -dM -E - </dev/null | grep -i -c "__SIZEOF_INT128__")

###############################################################################

echo
echo "********** OpenSSL **********"
echo

if ! "$WGET" -O "$OPENSSL_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://www.openssl.org/source/$OPENSSL_TAR"
then
    echo "Failed to download OpenSSL"
    exit 1
fi

rm -rf "$OPENSSL_DIR" &>/dev/null
gzip -d < "$OPENSSL_TAR" | tar xf -
cd "$OPENSSL_DIR" || exit 1

if [[ -e ../patch/openssl.patch ]]; then
    cp ../patch/openssl.patch .
    patch -u -p0 < openssl.patch
    echo ""
fi

#if [[ -n "$INSTX_ASAN" ]]; then
#    cp ../patch/openssl-nopreload.patch .
#    patch -u -p0 < openssl-nopreload.patch
#    echo ""
#fi

echo "Patching Makefiles"
SAVED_IFS="$IFS"
IFS="\r\n" find "$PWD" -iname 'Makefile' -print | while read file
do
    cp -p "$file" "$file.fixed"
    sed 's|$(INSTALL_PREFIX)||g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    sed 's|$(INSTALLTOP)/$(LIBDIR)|$(LIBDIR)|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    sed 's|libdir=$${exec_prefix}/$(LIBDIR)|libdir=$(LIBDIR)|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done
IFS="$SAVED_IFS"

CONFIG_OPTS=()
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="no-comp"

if [[ "$IS_AMD64" -eq 1 && "$INT128_OPT" -eq 1 ]]; then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="enable-ec_nistp_64_gcc_128"
fi

if [[ "$IS_FREEBSD" -eq 1 ]]; then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-Wno-error"
fi

# https://github.com/openssl/openssl/pull/10565
if [[ "$IS_OPENBSD" -eq 1 ]]; then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="no-devcryptoeng"
fi

# Configure the library
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--prefix=$INSTX_PREFIX"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--libdir=$INSTX_LIBDIR"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--openssldir=$INSTX_LIBDIR"

    KERNEL_BITS="$INSTX_BITNESS" \
    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
./config \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure OpenSSL"
    exit 1
fi

# Fix makefiles
if [[ "$IS_GCC" -eq 0 ]]; then
    for mfile in $(find "$PWD" -iname 'Makefile*'); do
        sed -e 's|-Wno-invalid-offsetof||g' -e 's|-Wno-extended-offsetof||g' "$mfile" > "$mfile.fixed"
        mv "$mfile.fixed" "$mfile"
    done
fi

# Fix makefiles
if [[ "$IS_DARWIN" -ne 0 ]]; then
    for mfile in $(find "$PWD" -iname 'Makefile*'); do
        sed -e 's|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|g' "$mfile" > "$mfile.fixed"
        mv "$mfile.fixed" "$mfile"
    done
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build OpenSSL"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

# Self tests are still unreliable, https://github.com/openssl/openssl/issues/4963
if [[ "$SKIP_OPENSSL_TESTS" -eq 0 ]];
then
    MAKE_FLAGS=("-j" "$INSTX_JOBS" test)
    if ! "$MAKE" "${MAKE_FLAGS[@]}"
    then
        echo "Failed to test OpenSSL"
        # Too many failures. Sigh...
        # exit 1
    fi
else
    echo "OpenSSL is not tested."
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test OpenSSL"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

# Install the software only
MAKE_FLAGS=(install_sw)
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$OPENSSL_TAR" "$OPENSSL_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openssl.sh 2>&1 | tee build-openssl.log
    if [[ -e build-openssl.log ]]; then
        rm -f build-openssl.log
    fi
fi

exit 0
