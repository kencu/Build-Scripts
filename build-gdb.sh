#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GDB from sources.

GDB_TAR=gdb-9.2.tar.gz
GDB_DIR=gdb-9.2

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

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    exit 1
fi

###############################################################################

if ! ./build-mpfr.sh
then
    echo "Failed to build MPFR"
    exit 1
fi

###############################################################################

if ! ./build-mpc.sh
then
    echo "Failed to build MPC"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= GDB =================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$GDB_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/gdb/$GDB_TAR"
then
    echo "Failed to download GDB"
    exit 1
fi

rm -rf "$GDB_DIR" &>/dev/null
gzip -d < "$GDB_TAR" | tar xf -
cd "$GDB_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/gdb.patch ]]; then
    patch -u -p0 < ../patch/gdb.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# GDB must be built in a directory different from its sources
mkdir -p build || exit 1
cd build || exit 1

CONFIG_OPTS=()
CONFIG_OPTS+=("--disable-lto")
CONFIG_OPTS+=("--with-mpc-include=$INSTX_PREFIX/include")
CONFIG_OPTS+=("--with-mpc-lib=$INSTX_LIBDIR")
CONFIG_OPTS+=("--with-mpfr-include=$INSTX_PREFIX/include")
CONFIG_OPTS+=("--with-mpfr-lib=$INSTX_LIBDIR")
CONFIG_OPTS+=("--with-gmp-include=$INSTX_PREFIX/include")
CONFIG_OPTS+=("--with-gmp-lib=$INSTX_LIBDIR")

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    ASFLAGS="${INSTX_ASFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="${INSTX_LIBS[*]}" \
../configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure GDB"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("MAKEINFO=true" "HELP2MAN=true" "-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build GDB"
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
    echo "Failed to test GDB"
    echo "**********************"
    exit 1
fi

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

    ARTIFACTS=("$GDB_TAR" "$GDB_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-gdb.sh 2>&1 | tee build-gdb.log
    if [[ -e build-gdb.log ]]; then
        rm -f build-gdb.log
    fi
fi

exit 0
