#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds SIP Witch from sources.

SIPW_TAR=sipwitch-1.9.15.tar.gz
SIPW_DIR=sipwitch-1.9.15

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

if ! ./build-libexosip2-rc.sh
then
    echo "Failed to build libosip2"
    exit 1
fi

###############################################################################

if ! ./build-ucommon.sh
then
    echo "Failed to build ucommon"
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "============== SIP Witch ==============="
echo "========================================"

echo ""
echo "***************************"
echo "Downloading package"
echo "***************************"

if ! "$WGET" -q -O "$SIPW_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/sipwitch/$SIPW_TAR"
then
    echo "Failed to download SIP Witch"
    exit 1
fi

rm -rf "$SIPW_DIR" &>/dev/null
gzip -d < "$SIPW_TAR" | tar xf -
cd "$SIPW_DIR" || exit 1

#cp common/voip.cpp common/voip.cpp.orig
#cp utils/sipquery.cpp utils/sipquery.cpp.orig
#cp server/stack.cpp server/stack.cpp.orig

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/sipwitch-rc.patch ]]; then
    patch -u -p0 < ../patch/sipwitch-rc.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

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
    --sysconfdir="$INSTX_PREFIX/etc" \
    --localstatedir="$INSTX_PREFIX/var" \
    --with-pkg-config \
    --with-libeXosip2=libeXosip2 \
    --enable-openssl

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure SIP Witch"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

# Fix makefiles again
IFS="" find "./" -iname 'Makefile' -print | while read -r file
do
    echo "$file" | sed 's/^\.\///g'

    touch -a -m -r "$file" "$file.timestamp.saved"
    chmod a+w "$file"
    sed -e "s/ libosip2/ -leXosip2/g" \
        -e "s/ libeXosip2/ -leXosip2/g" \
        "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod go-w "$file"
    touch -a -m -r "$file.timestamp.saved" "$file"
    rm "$file.timestamp.saved"
done

echo "***************************"
echo "Building package"
echo "***************************"

MAKE_FLAGS=("-k" "-j" "$INSTX_JOBS" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build SIP Witch"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

echo "***************************"
echo "Testing package"
echo "***************************"

MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "***************************"
    echo "Failed to test SIP Witch"
    echo "***************************"

    bash ../collect-logs.sh
    exit 1
fi

echo "***************************"
echo "Installing package"
echo "***************************"

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

# Set to true to retain artifacts
RETAIN_ARTIFACTS="${RETAIN_ARTIFACTS:-false}"
if [[ "${RETAIN_ARTIFACTS}" != "true" ]]; then

    ARTIFACTS=("$SIPW_TAR" "$SIPW_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-sipwitch.sh 2>&1 | tee build-sipwitch.log
    if [[ -e build-sipwitch.log ]]; then
        rm -f build-sipwitch.log
    fi
fi

exit 0
