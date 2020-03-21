#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds SSH and its dependencies from sources.
# Also see https://superuser.com/q/961349/173513.

OPENSSH_TAR=openssh-8.2p1.tar.gz
OPENSSH_DIR=openssh-8.2p1

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
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

# On OS X, requires OS X 10.10 or above
if [[ "$IS_DARWIN" -eq 0 || ("$IS_DARWIN" -eq 1 && "$OSX_1010_OR_ABOVE" -eq 1) ]]
then
    if ! ./build-ldns.sh
    then
        echo "Failed to build LDNS"
        exit 1
    fi
fi

###############################################################################

echo
echo "********** OpenSSH **********"
echo

if ! "$WGET" -O "$OPENSSH_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "http://ftp.usa.openbsd.org/pub/OpenBSD/OpenSSH/portable/$OPENSSH_TAR"
then
    echo "Failed to download SSH"
    exit 1
fi

rm -rf "$OPENSSH_DIR" &>/dev/null
gzip -d < "$OPENSSH_TAR" | tar xf -
cd "$OPENSSH_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

CONFIG_OPTS=()
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--prefix=$INSTX_PREFIX"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--libdir=$INSTX_LIBDIR"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-cppflags=${BUILD_CPPFLAGS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-cflags=${BUILD_CFLAGS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ldflags=${BUILD_CFLAGS[*]} ${BUILD_LDFLAGS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-libs=-lz ${BUILD_LIBS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-zlib=$INSTX_PREFIX"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ssl-dir=$INSTX_PREFIX"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-pie"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--disable-strip"

if [[ "$IS_DARWIN" -eq 0 || ("$IS_DARWIN" -eq 1 && "$OSX_1010_OR_ABOVE" -eq 1) ]]
then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ldns=$INSTX_PREFIX"
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_CFLAGS[*]} ${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure SSH"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build SSH"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

echo
echo "Unable to test OpenSSH"
echo 'https://groups.google.com/forum/#!topic/mailing.unix.openssh-dev/srdwaPQQ_Aw'
echo

# No way to test OpenSSH after build...
# https://groups.google.com/forum/#!topic/mailing.unix.openssh-dev/srdwaPQQ_Aw
#MAKE_FLAGS=("check" "V=1")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test SSH"
#    exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#    echo "Failed to test SSH"
#    exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
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

    ARTIFACTS=("$OPENSSH_TAR" "$OPENSSH_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openssh.sh 2>&1 | tee build-openssh.log
    if [[ -e build-openssh.log ]]; then
        rm -f build-openssh.log
    fi
fi

exit 0
