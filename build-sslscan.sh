#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds sslscan from sources.

SSLSCAN_TAR=2.0.0.tar.gz
SSLSCAN_DIR=sslscan-2.0.0

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
echo "================ sslscan ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$SSLSCAN_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://github.com/rbsec/sslscan/archive/$SSLSCAN_TAR"
then
    echo "Failed to download sslscan"
    exit 1
fi

rm -rf "$SSLSCAN_DIR" &>/dev/null
gzip -d < "$SSLSCAN_TAR" | tar xf -
cd "$SSLSCAN_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/sslscan.patch ]]; then
    patch -u -p0 < ../patch/sslscan.patch
    echo ""
fi

if ! "$WGET" -q -O Makefile --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://raw.githubusercontent.com/noloader/sslscan/master/Makefile"
then
    echo "Failed to update sslscan Makefile"
    exit 1
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
CPPFLAGS=$(echo "${INSTX_CPPFLAGS[*]}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS[*]}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS[*]}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS[*]}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LIBS[*]}"

MAKE_FLAGS=("all" "-j" "$INSTX_JOBS")
if ! CPPFLAGS="${CPPFLAGS}" \
     CFLAGS="${CFLAGS}" \
     CXXFLAGS="${CXXFLAGS}" \
     LDFLAGS="${LDFLAGS}" \
     LIBS="${LIBS}" \
     "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build sslscan"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test sslscan"
    echo "**********************"
    # exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install" "PREFIX=$INSTX_PREFIX" "LIBDIR=$INSTX_LIBDIR")
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

    ARTIFACTS=("$SSLSCAN_TAR" "$SSLSCAN_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-sslscan.sh 2>&1 | tee build-sslscan.log
    if [[ -e build-sslscan.log ]]; then
        rm -f build-sslscan.log
    fi
fi

exit 0
