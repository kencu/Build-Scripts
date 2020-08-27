#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Git and its dependencies from sources.

GIT_TAR=git-2.28.0.tar.gz
GIT_DIR=git-2.28.0

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
    echo "Failed to install CA certs"
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

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-openssl.sh
then
    echo "Failed to build OpenSSL"
    exit 1
fi

###############################################################################

if ! ./build-libexpat.sh
then
    echo "Failed to build Expat"
    exit 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

if ! ./build-curl.sh
then
    echo "Failed to build cURL"
    exit 1
fi

###############################################################################

# Required. For Solaris see https://community.oracle.com/thread/1915569.
if ! perl -MExtUtils::MakeMaker -e1 2>/dev/null
then
    echo ""
    echo "Git requires Perl's ExtUtils::MakeMaker."
    echo "To fix this issue, please install ExtUtils-MakeMaker."
    exit 1
fi

###############################################################################

echo ""
echo "========================================"
echo "================= Git =================="
echo "========================================"

echo ""
echo "**********************"
echo "Downloading package"
echo "**********************"

if ! "$WGET" -q -O "$GIT_TAR" --ca-certificate="$CA_ZOO" \
     "https://mirrors.edge.kernel.org/pub/software/scm/git/$GIT_TAR"
then
    echo "Failed to download Git."
    exit 1
fi

rm -rf "$GIT_DIR" &>/dev/null
gzip -d < "$GIT_TAR" | tar xf -
cd "$GIT_DIR" || exit 1

if [[ -e ../patch/git.patch ]]; then
    patch -u -p0 < ../patch/git.patch
    echo ""
fi

# Fix sys_lib_dlsearch_path_spec
bash ../fix-configure.sh

echo "**********************"
echo "Configuring package"
echo "**********************"

# Command line tools, like sed and awk, need this on OS X.
if [[ "$IS_DARWIN" -ne 0 ]]
then
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    export LANG="${LANG:-en_US.UTF-8}"
fi

echo "**********************"
echo "Building configure"
echo "**********************"

if ! "${MAKE}" configure
then
    echo "Failed to make configure Git"
    exit 1
fi

# Solaris 11.3 no longer has /usr/ucb/install
if [[ "$IS_SOLARIS" -ne 0 ]]
then

    IFS="" find "$PWD" -iname 'config*' -print | while read -r file
    do
        if [[ ! -f "$file" ]]; then continue; fi

        touch -a -m -r "$file" "$file.timestamp"
        chmod u+w "$file" && cp -p "$file" "$file.fixed"

        sed -e 's/\/usr\/ucb//g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"

        chmod a+x "$file" && chmod go-w "$file"
        touch -a -m -r "$file.timestamp" "$file"
        rm "$file.timestamp"
    done
fi

if [[ -e /usr/local/bin/perl ]]; then
    GIT_PERL=/usr/local/bin/perl
elif [[ -e /usr/bin/perl ]]; then
    GIT_PERL=/usr/bin/perl
else
    GIT_PERL=perl
fi

    CURLDIR="$INSTX_PREFIX" \
    CURL_CONFIG="$INSTX_PREFIX/bin/curl-config" \
    PKG_CONFIG_PATH="${INSTX_PKGCONFIG[*]}" \
    CPPFLAGS="${INSTX_CPPFLAGS[*]} -DNO_UNALIGNED_LOADS=1" \
    ASFLAGS="${INSTX_ASFLAGS[*]}" \
    CFLAGS="${INSTX_CFLAGS[*]}" \
    CXXFLAGS="${INSTX_CXXFLAGS[*]}" \
    LDFLAGS="${INSTX_LDFLAGS[*]}" \
    LIBS="-lssl -lcrypto -lz ${INSTX_LIBS[*]}" \
./configure \
    --build="$AUTOCONF_BUILD" \
    --prefix="$INSTX_PREFIX" \
    --libdir="$INSTX_LIBDIR" \
    --with-lib="$(basename "$INSTX_LIBDIR")" \
    --with-sane-tool-path="$INSTX_PREFIX/bin" \
    --enable-pthreads \
    --with-openssl="$INSTX_PREFIX" \
    --with-curl="$INSTX_PREFIX" \
    --with-libpcre="$INSTX_PREFIX" \
    --with-zlib="$INSTX_PREFIX" \
    --with-iconv="$INSTX_PREFIX" \
    --with-expat="$INSTX_PREFIX" \
    --with-perl="$GIT_PERL" \
    --without-tcltk

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Git"
    exit 1
fi

# Fix LD_LIBRARY_PATH and DYLD_LIBRARY_PATH
bash ../fix-ld-library-path.sh

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")

# Disables message translation if msgfmt is missing.
if [[ -z $(command -v msgfmt) ]]; then
    MAKE_FLAGS[${#MAKE_FLAGS[@]}]="NO_GETTEXT=Yes"
fi
# Disables GUI if TCL is missing.
if [[ -z $(command -v tclsh) ]]; then
    MAKE_FLAGS[${#MAKE_FLAGS[@]}]="NO_TCLTK=Yes"
fi

# Escape dollar sign for $ORIGIN in makefiles. Required so
# $ORIGIN works in both configure tests and makefiles.
bash ../fix-makefiles.sh

echo "**********************"
echo "Building package"
echo "**********************"

if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Git"
    exit 1
fi

# Fix flags in *.pc files
bash ../fix-pkgconfig.sh

# Fix runpaths
bash ../fix-runpath.sh

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("test" "V=1")
if ! "${MAKE}" "${MAKE_FLAGS[@]}"
then
    echo "**********************"
    echo "Failed to test Git"
    echo "**********************"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

# See INSTALL for the formats and the requirements
MAKE_FLAGS=("install")

# Git builds things during install, and they end up root:root.
# The chmod allows us to remove them at cleanup. Can't use octal
# due to OS X 10.5 on PowerMac.
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S "${MAKE}" "${MAKE_FLAGS[@]}"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chmod -R a+rwx ./*
else
    "${MAKE}" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR" || exit 1

###############################################################################

if [[ -z $(git config --get http.sslCAInfo) ]];
then
    echo ""
    echo "*****************************************************************************"
    echo "Configuring Git to use CA store at $OPT_CACERT_PATH/cacert.pem"
    echo "*****************************************************************************"

    git config --global http.sslCAInfo "$OPT_CACERT_FILE"
else
    echo ""
    echo "*****************************************************************************"
    echo "Git already configured to use CA store at $(git config --get http.sslCAInfo)"
    echo "*****************************************************************************"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GIT_TAR" "$GIT_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-git.sh 2>&1 | tee build-git.log
    if [[ -e build-git.log ]]; then
        rm -f build-git.log
    fi
fi

exit 0
