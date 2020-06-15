#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds iConv and Gettext from sources.

# iConvert and GetText are unique among packages. They have circular
# dependencies on one another. We have to build iConv, then GetText,
# and iConv again. Also see https://www.gnu.org/software/libiconv/.

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

if [[ -e "$INSTX_PKG_CACHE/iconv" ]] && [[ -e "$INSTX_PKG_CACHE/gettext" ]]; then
    echo ""
    echo "iConv and GetText already installed."
    exit 0
fi

###############################################################################

# Rebuild them as a pair
rm -rf "$INSTX_PKG_CACHE/iconv"
rm -rf "$INSTX_PKG_CACHE/gettext"

###############################################################################

# pkg-config is special
export INSTX_DISABLE_ICONV_TEST=1

if [[ "$IS_DARWIN" -ne 0 ]]
then
    if ! ./build-iconv-utf8mac.sh
    then
        echo "Failed to build iConv and GetText (1st time)"
        exit 1
    fi
else
    if ! ./build-iconv.sh
    then
        echo "Failed to build iConv and GetText (1st time)"
        exit 1
    fi
fi

unset INSTX_DISABLE_ICONV_TEST

###############################################################################

if ! ./build-gettext.sh
then
    echo "Failed to build GetText"
    exit 1
fi

###############################################################################

# Due to circular dependency. Once GetText is built, we need
# to build iConvert again so it picks up the new GetText.
rm "$INSTX_PKG_CACHE/iconv"

if ! ./build-iconv.sh
then
    echo "Failed to build iConv and GetText (2nd time)"
    exit 1
fi

exit 0
