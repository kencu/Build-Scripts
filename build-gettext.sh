#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds GetText from sources.

# iConvert and GetText are unique among packages. They have circular
# dependencies on one another. We have to build iConv, then GetText,
# and iConv again. Also see https://www.gnu.org/software/libiconv/.
# The script that builds iConvert and GetText in accordance to specs
# is build-iconv-gettext.sh. You should use build-iconv-gettext.sh
# instead of build-gettext.sh directly

GETTEXT_VER=0.21
GETTEXT_TAR="gettext-${GETTEXT_VER}.tar.gz"
GETTEXT_DIR="gettext-${GETTEXT_VER}"
PKG_NAME=gettext

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

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
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

if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

if ! ./build-ncurses-readline.sh
then
    echo "Failed to build Ncurses and Readline"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "=============== GetText ================"
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

if ! "$WGET" -q -O "$GETTEXT_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/gettext/$GETTEXT_TAR"
then
    echo "Failed to download GetText"
    exit 1
fi

rm -rf "$GETTEXT_DIR" &>/dev/null
gzip -d < "$GETTEXT_TAR" | tar xf -
cd "$GETTEXT_DIR" || exit 1

# find . -type f -name 'xalloc.h' -print0 | xargs --null -I{} cp {} {}.orig
# find . -type f -name 'xalloc-oversized.h' -print0 | xargs --null -I{} cp {} {}.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/gettext.patch ]]; then
    patch -u -p0 < ../patch/gettext.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

# Some non-GNU systems have Gzip, but it is anemic.
# GZIP_ENV = --best causes an autopoint-3 test failure.
IFS="" find "$PWD" -name 'Makefile.in' -print | while read -r file
do
    sed -e 's/GZIP_ENV = --best/GZIP_ENV = -7/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

if [ -e "$INSTX_PREFIX/bin/sed" ]; then
    export SED="$INSTX_PREFIX/bin/sed"
fi

echo "***************************"
echo "Configuring package"
echo "***************************"

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
    --libdir="$INSTX_LIBDIR" \
    --enable-static \
    --enable-shared \
    --with-pic \
    --with-included-gettext \
    --with-included-libxml \
    --with-included-libunistring \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libncurses-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]
then
    echo "***************************"
    echo "Failed to configure GetText"
    echo "***************************"

    bash ../collect-logs.sh
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to build GetText"
    echo "***************************"

    bash ../collect-logs.sh
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "***************************"
echo "Testing package"
echo "***************************"

MAKE_FLAGS=("check")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to test GetText"
    echo "***************************"

    bash ../collect-logs.sh

    # Solaris and some friends fail lang-gawk
    # Darwin fails copy-acl-2.sh
    # https://lists.gnu.org/archive/html/bug-gawk/2018-01/msg00026.html
    # exit 1
fi

# Fix runpaths again
bash ../fix-runpath.sh

echo "***************************"
echo "Installing package"
echo "***************************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S rm -rf "$INSTX_PREFIX/share/doc/gettext"
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
    rm -rf "$INSTX_PREFIX/share/doc/gettext"
fi

cd "$CURR_DIR" || exit 1

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true;
then
    ARTIFACTS=("$GETTEXT_TAR" "$GETTEXT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done
fi

exit 0
