#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Zile from sources.

ZILE_TAR=zile-2.4.14.tar.gz
ZILE_DIR=zile-2.4.14

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

if ! ./build-termcap.sh
then
    echo "Failed to build Termcap"
    exit 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build Ncurses"
    exit 1
fi

###############################################################################

echo
echo "********** Zile **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$ZILE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/zile/$ZILE_TAR"
then
    echo "Failed to download Zile"
    exit 1
fi

rm -rf "$ZILE_DIR" &>/dev/null
gzip -d < "$ZILE_TAR" | tar xf -
cd "$ZILE_DIR"

if [[ -e ../patch/zile.patch ]]; then
    cp ../patch/zile.patch .
    patch -u -p0 < zile.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

CONFIG_OPTS=()
CONFIG_OPTS+=("--build=$AUTOCONF_BUILD")
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--enable-debug=no")
CONFIG_OPTS+=("HELP2MAN=true")

if [[ "$IS_SOLARIS" -ne 0 ]]; then
    CONFIG_OPTS+=("--enable-threads=solaris")
else
    CONFIG_OPTS+=("--enable-threads=posix")
fi

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne "0" ]]; then
    echo "Failed to configure Zile"
    exit 1
fi

echo "Patching Makefiles..."
(IFS="" find "$PWD" -name 'Makefile' -print | while read -r file
do
    cp -p "$file" "$file.fixed"
    sed 's|-lncurses|-lncurses -ltinfo|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Zile"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pkgconfig.sh .
./fix-pkgconfig.sh

echo "**********************"
echo "Testing package"
echo "**********************"

#MAKE_FLAGS=("check")
#if ! "$MAKE" "${MAKE_FLAGS[@]}"
#then
#    echo "Failed to test Zile"
#    exit 1
#fi

#echo "Searching for errors hidden in log files"
#COUNT=$(find . -name '*.log' | grep -oIR 'runtime error:' ./* | wc -l)
#if [[ "${COUNT}" -ne 0 ]];
#then
#	echo "Failed to test Zile"
#	exit 1
#fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ ! ("$SUDO_PASSWORD_SET" != "yes") ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$THIS_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if false; then

    ARTIFACTS=("$ZILE_TAR" "$ZILE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-zile.sh 2>&1 | tee build-zile.log
    if [[ -e build-zile.log ]]; then
        rm -f build-zile.log
    fi
fi

exit 0
