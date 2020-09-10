#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds SSM from sources.

SSM_TAR=v1.4.tar.gz
SSM_DIR=ssm-1.4

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

echo ""
echo "========================================"
echo "================== SSM =================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$SSM_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://github.com/system-storage-manager/ssm/archive/$SSM_TAR"
then
    echo "Failed to download SSM"
    exit 1
fi

rm -rf "$SSM_DIR" &>/dev/null
gzip -d < "$SSM_TAR" | tar xf -
cd "$SSM_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/ssm.patch ]]; then
    patch -u -p0 < ../patch/ssm.patch
    echo ""
fi

echo "**********************"
echo "Building package"
echo "**********************"

if ! python setup.py build
then
    echo "**********************"
    echo "Failed to build SSM"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

if ! python test.py
then
    echo "**********************"
    echo "Failed to test SSM"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S python setup.py install --prefix="$INSTX_PREFIX"
else
    python setup.py install --prefix="$INSTX_PREFIX"
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

    ARTIFACTS=("$SSM_TAR" "$SSM_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ssm.sh 2>&1 | tee build-ssm.log
    if [[ -e build-ssm.log ]]; then
        rm -f build-ssm.log
    fi
fi

exit 0
