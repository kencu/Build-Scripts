#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds b2sum from sources.

B2SUM_TAR=20190724.tar.gz
B2SUM_DIR=BLAKE2-20190724

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

# BLAKE2 only has benchmarks for Intel machines
if [ "$IS_IA32" -ne 0 ]
then
    if ! ./build-openssl.sh
    then
        echo "Failed to build OpenSSL"
        exit 1
    fi
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

if [[ -e ../patch/b2sum.patch ]]; then
    patch -u -p0 < ../patch/b2sum.patch
    echo ""
fi

# The Makefiles needed so much work it was easier to provide Autotools for them.
# The files were offered to BLAKE2 at https://github.com/BLAKE2/BLAKE2/pull/63.
if [[ -e ../patch/b2sum-autotools.zip ]]; then
    cp ../patch/b2sum-autotools.zip .
    unzip -oq b2sum-autotools.zip
fi

echo "**********************"
echo "Bootstrapping package"
echo "**********************"

if ! autoreconf --install --force 1>/dev/null
then
    echo "***************************"
    echo "Failed to bootstrap package"
    echo "***************************"
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
    --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure b2sum"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "Makefile" "V=1")
MAKE_FLAGS+=("-j" "$INSTX_JOBS")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build b2sum"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test b2sum"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "PREFIX=$INSTX_PREFIX")
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
