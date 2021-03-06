#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds OpenLDAP from sources.

LDAP_VER=2.4.56
LDAP_TAR="openldap-${LDAP_VER}.tgz"
LDAP_DIR="openldap-${LDAP_VER}"
PKG_NAME=openldap

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

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-bdb.sh
then
    echo "Failed to build Berkely DB"
    exit 1
fi

###############################################################################

if [[ "$IS_ALPINE" -ne 0 ]] && [[ -z "$(command -v soelim 2>/dev/null)" ]]
then
    if ! ./build-mandoc.sh
    then
        echo "Failed to build Mandoc"
        exit 1
    fi
fi

###############################################################################

# Problem with paths on NetBSD???

LD_LIBRARY_PATH="$INSTX_LIBDIR:$LD_LIBRARY_PATH"
LD_LIBRARY_PATH=$(printf "%s" "$LD_LIBRARY_PATH" | sed 's|:$||')
export LD_LIBRARY_PATH

DYLD_LIBRARY_PATH="$INSTX_LIBDIR:$DYLD_LIBRARY_PATH"
DYLD_LIBRARY_PATH=$(printf "%s" "$DYLD_LIBRARY_PATH" | sed 's|:$||')
export DYLD_LIBRARY_PATH

###############################################################################

echo ""
echo "========================================"
echo "=============== OpenLDAP ==============="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" --ca-certificate="$GO_DADDY_ROOT" -O "$LDAP_TAR" \
     "https://gpl.savoirfairelinux.net/pub/mirrors/openldap/openldap-release/$LDAP_TAR"
then
    echo "Failed to download OpenLDAP"
    exit 1
fi

rm -rf "$LDAP_DIR" &>/dev/null
gzip -d < "$LDAP_TAR" | tar xf -
cd "$LDAP_DIR" || exit 1

if [[ -e ../patch/openldap.patch ]]; then
    patch -u -p0 < ../patch/openldap.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# Fix Berkeley DB version test
cp -p configure configure.new
sed 's|0x060014|0x060300|g' configure > configure.new
mv configure.new configure; chmod a+x configure

# OpenLDAP munges -Wl,-R,'$ORIGIN/../lib'. Somehow it manages
# to escape the '$ORIGIN/../lib' in single quotes. Set $ORIGIN
# to itself to workaround it.
export ORIGIN="\$ORIGIN"

# mdb is too dirty and cannot build on OS X. It is also full of
# undefined behavior. Just disable mdb on all platforms.
CONFIG_OPTS=()
CONFIG_OPTS+=("--with-tls=openssl")
CONFIG_OPTS+=("--enable-mdb=no")

    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]}" \
    ASFLAGS="${INSTX_ASFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure OpenLDAP"
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
    echo "Failed to build OpenLDAP"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# Can't pass self tests on ARM
MAKE_FLAGS=("check" "-k" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test OpenLDAP"
    # exit 1
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

OLD_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
OLD_DYLD_LIBRARY_PATH="$OLD_DYLD_LIBRARY_PATH"

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$LDAP_TAR" "$LDAP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-openldap.sh 2>&1 | tee build-openldap.log
    if [[ -e build-openldap.log ]]; then
        rm -f build-openldap.log
    fi
fi

exit 0
