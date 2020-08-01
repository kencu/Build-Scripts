#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Emacs and its dependencies from sources.

EMACS_TAR=emacs-26.3.tar.gz
EMACS_DIR=emacs-26.3

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

if ! ./build-zlib.sh
then
    echo "Failed to build zLib"
    exit 1
fi

###############################################################################

if ! ./build-bzip.sh
then
    echo "Failed to build Bzip2"
    exit 1
fi

###############################################################################

if ! ./build-ncurses.sh
then
    echo "Failed to build Ncurses"
    exit 1
fi

###############################################################################

if ! ./build-libxml2.sh
then
    echo "Failed to build libxml2"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================ Emacs ================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$EMACS_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/emacs/$EMACS_TAR"
then
    echo "Failed to download Emacs"
    exit 1
fi

rm -rf "$EMACS_DIR" &>/dev/null
gzip -d < "$EMACS_TAR" | tar xf -
cd "$EMACS_DIR"

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

CONFIG_OPTS=('--with-xml2' '--without-x' '--without-sound' '--without-xpm'
    '--without-jpeg' '--without-tiff' '--without-gif' '--without-png'
    '--without-rsvg' '--without-imagemagick' '--without-xft' '--without-libotf'
    '--without-m17n-flt' '--without-xaw3d' '--without-toolkit-scroll-bars'
    '--without-gpm' '--without-dbus' '--without-gconf' '--without-gsettings'
    '--without-makeinfo' '--without-compress-install' '--with-gnutls=no')

if [[ -e "/usr/include/selinux/context.h" ]]; then
    CONFIG_OPTS+=('--with-selinux')
fi

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
    echo "Failed to configure emacs"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
   echo "Failed to test Emacs"
   exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

#echo "**********************"
#echo "Testing package"
#echo "**********************"

#MAKE_FLAGS=("check" "V=1")
#if ! "${MAKE}" "${MAKE_FLAGS[@]}"
#then
#   echo "Failed to test Emacs"
#   exit 1
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

    ARTIFACTS=("$EMACS_TAR" "$EMACS_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-emacs.sh 2>&1 | tee build-emacs.log
    if [[ -e build-emacs.log ]]; then
        rm -f build-emacs.log
    fi
fi

exit 0
