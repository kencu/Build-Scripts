#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Ncurses from sources.

# Do NOT use Ncurses 6.2. There are too many problems with the release.
# Wait for the Ncurses 6.3 release.

NCURSES_VER=6.1
NCURSES_TAR="ncurses-${NCURSES_VER}.tar.gz"
NCURSES_DIR="ncurses-${NCURSES_VER}"
PKG_NAME=ncurses

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

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
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

if ! ./build-patchelf.sh
then
    echo "Failed to build patchelf"
    exit 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

echo
echo "********** ncurses **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$NCURSES_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/pub/gnu/ncurses/$NCURSES_TAR"
then
    echo "Failed to download Ncurses"
    exit 1
fi

rm -rf "$NCURSES_DIR" &>/dev/null
gzip -d < "$NCURSES_TAR" | tar xf -
cd "$NCURSES_DIR" || exit 1

# Don't apply patches. It breaks things even more. Sigh...
if false; then

# https://invisible-island.net/ncurses/ncurses.faq.html#applying_patches
if "$WGET" -q -O dev-patches.zip --ca-certificate="$LETS_ENCRYPT_ROOT" \
   "ftp://ftp.invisible-island.net/ncurses/${NCURSES_VER}/dev-patches.zip"
then
    if unzip dev-patches.zip -d .
    then
        echo "********************************"
        echo "Applying Ncurses patches"
        echo "********************************"
        for p in ncurses-*.patch.gz ;
        do
            echo "Applying ${p}"
            zcat "${p}" | patch -s -p1
        done
    else
        echo "********************************"
        echo "Failed to unpack Ncurses patches"
        echo "********************************"
        exit 1
    fi
else
    echo "**********************************"
    echo "Failed to download Ncurses patches"
    echo "**********************************"
    exit 1
fi

fi

if [[ -e ../patch/ncurses.patch ]]; then
    patch -u -p0 < ../patch/ncurses.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=()
CONFIG_OPTS+=("--disable-leaks")
CONFIG_OPTS+=("--with-shared")
CONFIG_OPTS+=("--with-cxx-shared")
CONFIG_OPTS+=("--with-termlib")
CONFIG_OPTS+=("--enable-pc-files")
CONFIG_OPTS+=("--disable-root-environ")
CONFIG_OPTS+=("--with-pkg-config-libdir=${INSTX_PKGCONFIG[*]}")
CONFIG_OPTS+=("--with-default-terminfo-dir=$INSTX_PREFIX/share")

# Ncurses can be built narrow or wide. There's no way to know for sure
# which is needed, so we attempt to see what the distro is doing. If we
# find wide version, then we configure for the wide version.
COUNT=$(find /usr/lib/ /usr/lib64/ -name 'ncurses*w.*' 2>/dev/null | wc -l)
if [[ "$COUNT" -ne 0 ]]; then
    echo "Enabling wide character version"
    echo ""
    CONFIG_OPTS+=("--enable-widec")
else
    echo "Enabling narrow character version"
    echo ""
fi

    # Ncurses use PKG_CONFIG_LIBDIR, not PKG_CONFIG_PATH???
    PKG_CONFIG_LIBDIR="${INSTX_PKGCONFIG[*]}" \
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
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure ncurses"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

# Remove unneeded warning
(IFS="" find "$PWD" -name 'Makefile' -print | while read -r file
do
    cp -p "$file" "$file.fixed"
    sed 's/ --param max-inline-insns-single=1200//g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to build ncurses"
    echo "**********************"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("test")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test ncurses"
    echo "**********************"
    exit 1
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
if true; then

    ARTIFACTS=("$NCURSES_TAR" "$NCURSES_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-ncurses.sh 2>&1 | tee build-ncurses.log
    if [[ -e build-ncurses.log ]]; then
        rm -f build-ncurses.log
    fi
fi

exit 0
