#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Cpuid from sources.

CPUID_TAR=cpuid-20180519.src.tar.gz
CPUID_DIR=cpuid-20180519
PKG_NAME=cpuid

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

# Bail early
if [[ $(uname -m 2>/dev/null | grep -i -c -E 'i86pc|i.86|amd64|x86_64') -eq 0 ]]
then
    echo "Failed to build cpuid. The program is only valid for x86 platforms."
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
echo "********** Cpuid **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$CPUID_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "http://www.etallen.com/cpuid/$CPUID_TAR"
then
    echo "Failed to download Cpuid"
    exit 1
fi

rm -rf "$CPUID_DIR" &>/dev/null
gzip -d < "$CPUID_TAR" | tar xf -
cd "$CPUID_DIR"

if [[ -e ../patch/cpuid.patch ]]; then
    patch -u -p0 < ../patch/cpuid.patch
    echo ""
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}"
CPPFLAGS=$(echo "${INSTX_CPPFLAGS[*]}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS[*]}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS[*]}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS[*]}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LIBS[*]}"

MAKE_FLAGS=()
MAKE_FLAGS+=("-f" "$MAKEFILE")
MAKE_FLAGS+=("-j" "$INSTX_JOBS")
MAKE_FLAGS+=("CPPFLAGS=${CPPFLAGS} -I.")
MAKE_FLAGS+=("CFLAGS=${CFLAGS}")
MAKE_FLAGS+=("CXXFLAGS=${CXXFLAGS}")
MAKE_FLAGS+=("LDFLAGS=${LDFLAGS}")
MAKE_FLAGS+=("LIBS=${LIBS}")

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build cpuid"
    exit 1
fi

#echo "**********************"
#echo "Testing package"
#echo "**********************"

# No make check program
#MAKE_FLAGS=("check")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Cpuid"
#    exit 1
#fi

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

    ARTIFACTS=("$CPUID_TAR" "$CPUID_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-cpuid.sh 2>&1 | tee build-cpuid.log
    if [[ -e build-cpuid.log ]]; then
        rm -f build-cpuid.log
    fi
fi

exit 0
