#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds mandoc from sources.

MANDOC_TAR=mandoc-1.14.5.tar.gz
MANDOC_DIR=mandoc-1.14.5

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

echo
echo "********** MANDOC **********"
echo

echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$MANDOC_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://mandoc.bsd.lv/snapshots/$MANDOC_TAR"
then
    echo "Failed to download MANDOC"
    exit 1
fi

rm -rf "$MANDOC_DIR" &>/dev/null
gzip -d < "$MANDOC_TAR" | tar xf -
cd "$MANDOC_DIR" || exit 1

# Patches are created with 'diff -u' from the pkg root directory.
if [[ -e ../patch/mandoc.patch ]]; then
    patch -u -p0 < ../patch/mandoc.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# Since we call the makefile directly, we need to escape dollar signs.
PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}"
CPPFLAGS=$(echo "${INSTX_CPPFLAGS[*]}" | sed 's/\$/\$\$/g')
ASFLAGS=$(echo "${INSTX_ASFLAGS[*]}" | sed 's/\$/\$\$/g')
CFLAGS=$(echo "${INSTX_CFLAGS[*]}" | sed 's/\$/\$\$/g')
CXXFLAGS=$(echo "${INSTX_CXXFLAGS[*]}" | sed 's/\$/\$\$/g')
LDFLAGS=$(echo "${INSTX_LDFLAGS[*]}" | sed 's/\$/\$\$/g')
LIBS="${INSTX_LIBS[*]}"

echo "" > configure.local
{
    echo "PREFIX='$INSTX_PREFIX'"
    echo "BINDIR='\${PREFIX}/bin'"
    echo "SBINDIR='\${PREFIX}/sbin'"
    echo "MANDIR='\${PREFIX}/man'"

    echo "CC='$CC'"
    echo "ASFLAGS='${ASFLAGS}'"
    echo "CFLAGS='${CPPFLAGS} ${CFLAGS} -I.'"
    echo "LDFLAGS='${LDFLAGS}'"
    echo "LDADD='${LIBS}'"

    echo ""
}  >> configure.local

# Mandoc uses configure.local
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure MANDOC"
    exit 1
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("MAKEINFO=true" "-j" "$INSTX_JOBS")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build MANDOC"
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

    ARTIFACTS=("$MANDOC_TAR" "$MANDOC_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-mandoc.sh 2>&1 | tee build-mandoc.log
    if [[ -e build-mandoc.log ]]; then
        rm -f build-mandoc.log
    fi
fi

exit 0
