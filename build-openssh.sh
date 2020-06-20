#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds SSH and its dependencies from sources.
# Also see https://superuser.com/q/961349/173513.

OPENSSH_TAR=openssh-8.3p1.tar.gz
OPENSSH_DIR=openssh-8.3p1

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

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$OPENSSH_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "http://ftp.usa.openbsd.org/pub/OpenBSD/OpenSSH/portable/$OPENSSH_TAR"
then
    echo "Failed to download SSH"
    exit 1
fi

rm -rf "$OPENSSH_DIR" &>/dev/null
gzip -d < "$OPENSSH_TAR" | tar xf -
cd "$OPENSSH_DIR" || exit 1

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

CONFIG_OPTS=()
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-cppflags=${INSTX_CPPFLAGS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-cflags=${INSTX_CFLAGS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ldflags=${INSTX_CFLAGS[*]} ${INSTX_LDFLAGS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-libs=-lz ${INSTX_LIBS[*]}"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-zlib=$INSTX_PREFIX"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ssl-dir=$INSTX_PREFIX"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-pie"
CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--disable-strip"

if [[ "$IS_DARWIN" -eq 0 || ("$IS_DARWIN" -eq 1 && "$OSX_1010_OR_ABOVE" -eq 1) ]]
then
    CONFIG_OPTS[${#CONFIG_OPTS[@]}]="--with-ldns=$INSTX_PREFIX"
fi

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_CFLAGS[*]} ${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure SSH"
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
    echo "Failed to build SSH"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

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
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test SSH"
#    exit 1
#fi

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
