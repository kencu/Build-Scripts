#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds b2sum from sources.

B2SUM_TAR=20160619.tar.gz
B2SUM_DIR=BLAKE2-20160619

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

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

echo
echo "********** b2sum **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$B2SUM_TAR" --ca-certificate="$GITHUB_ROOT" \
     "https://github.com/BLAKE2/BLAKE2/archive/$B2SUM_TAR"
then
    echo "Failed to download b2sum"
    exit 1
fi

rm -rf "$B2SUM_DIR" &>/dev/null
gzip -d < "$B2SUM_TAR" | tar xf -
cd "$B2SUM_DIR"

# cp sse/blake2s-load-sse2.h sse/blake2s-load-sse2.h.orig
# cp sse/blake2b-load-sse2.h sse/blake2b-load-sse2.h.orig

if [[ -e ../patch/b2sum.patch ]]
then
    cp ../patch/b2sum.patch .
    patch -u -p0 < b2sum.patch
    echo ""
fi

cd "b2sum"

B2SUM_CFLAGS="${BUILD_CPPFLAGS[@]} ${BUILD_CFLAGS[@]} -std=c99 -I."

# Unconditionally remove OpenMP from makefile
sed "/^NO_OPENMP/d" makefile > makefile.fixed
mv makefile.fixed makefile

# Breaks compile on some platforms
sed "s|-Werror=declaration-after-statement ||g" makefile > makefile.fixed
mv makefile.fixed makefile

# Remove all CFLAGS. We build our own list
sed "/^CFLAGS/d" makefile > makefile.fixed
mv makefile.fixed makefile

# Either use the SSE files, or remove the SSE source files
if [[ "$IS_IA32" -ne 0 ]]; then
    B2SUM_CFLAGS="$B2SUM_CFLAGS -I../sse -msse2"
    sed "/^#FILES=/d" makefile > makefile.fixed
    mv makefile.fixed makefile
else
    B2SUM_CFLAGS="$B2SUM_CFLAGS -I../ref"
    sed "/^FILES=/d" makefile > makefile.fixed
    mv makefile.fixed makefile
    sed "s|^#FILES=|FILES=|g" makefile > makefile.fixed
    mv makefile.fixed makefile
fi

# Add OpenMP if available
if [[ -n "$SH_OPENMP" ]]; then
    B2SUM_CFLAGS="$B2SUM_CFLAGS $SH_OPENMP"
fi

if [[ "$IS_SOLARIS" -eq 1 ]]; then
    CC=gcc
    sed 's|CC?=gcc|CC=gcc|g' makefile > makefile.fixed
    mv makefile.fixed makefile
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("CFLAGS=$B2SUM_CFLAGS" "-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build b2sum"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../../fix-pc.sh .; ./fix-pc.sh

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# Ugh, no 'check' or 'test' targets
#MAKE_FLAGS=("check")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test b2sum"
#    exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test b2sum"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "PREFIX=$INSTX_PREFIX")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$B2SUM_TAR" "$B2SUM_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-b2sum.sh 2>&1 | tee build-b2sum.log
    if [[ -e build-b2sum.log ]]; then
        rm -f build-b2sum.log
    fi
fi

exit 0
