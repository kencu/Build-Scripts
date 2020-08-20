#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds iConv from sources.

# iConv and GetText are unique among packages. They have circular
# dependencies on one another. We have to build iConv, then GetText,
# and iConv again. Also see https://www.gnu.org/software/libiconv/.
# The script that builds iConvert and GetText in accordance to specs
# is build-iconv-gettext.sh. You should use build-iconv-gettext.sh
# instead of build-iconv.sh directly

# iConv has additional hardships. The maintainers don't approve of
# Apple's UTF-8-Mac so they don't support it. Lack of UTF-8-Mac support
# on OS X causes other programs to fail, like Git. Also see
# https://marc.info/?l=git&m=158857581228100. That leaves two choices.
# First, use a GitHub like https://github.com/fumiyas/libiconv.
# Second, use Apple's sources at http://opensource.apple.com/tarballs/.
# Apple's libiconv-59 is really libiconv 1.11 in disguise. So we use
# the first method, clone libiconv, build a release tarball,
# and then use it in place of the GNU package.

ICONV_TAR=libiconv-1.16.tar.gz
ICONV_DIR=libiconv-1.16
PKG_NAME=iconv

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

# Sets the number of make jobs if not set in environment
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

if ! ./build-ncurses.sh
then
    echo "Failed to build Ncurses"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ iConv ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$ICONV_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/libiconv/$ICONV_TAR"
then
    echo echo "Failed to download iConv"
    exit 1
fi

rm -rf "$ICONV_DIR" &>/dev/null
gzip -d < "$ICONV_TAR" | tar xf -
cd "$ICONV_DIR" || exit 1

# libiconv-utf8mac already has patch applied
# libiconv still needs the patch
if [[ -e ../patch/iconv.patch ]]; then
    patch -u -p0 < ../patch/iconv.patch
    echo ""
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
    --libdir="$INSTX_LIBDIR" \
    --enable-shared \
    --with-libintl-prefix="$INSTX_PREFIX"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure iConv"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build iConv"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

# build-iconv-gettext has a circular dependency.
# The first build of iConv does not need 'make check'.
if [[ "${INSTX_DISABLE_ICONV_TEST:-0}" -ne 1 ]]
then
    echo "**********************"
    echo "Testing package"
    echo "**********************"

    MAKE_FLAGS=("check" "V=1")
    if ! "${MAKE}" "${MAKE_FLAGS[@]}"
    then
        echo "**********************"
        echo "Failed to test package"
        echo "**********************"

        RETAIN_ARTIFACTS=true
        bash ../collect-logs.sh

        exit 1
    fi
fi

# Fix runpaths again
bash ../fix-runpath.sh

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

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
RETAIN_ARTIFACTS="${RETAIN_ARTIFACTS:-false}"
if [[ "${RETAIN_ARTIFACTS}" != "true" ]]; then

    ARTIFACTS=("$ICONV_TAR" "$ICONV_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-iconv.sh 2>&1 | tee build-iconv.log
    if [[ -e build-iconv.log ]]; then
        rm -f build-iconv.log
    fi
fi

exit 0
