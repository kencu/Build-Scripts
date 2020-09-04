#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds iConv and Gettext from sources.

# Ncurses and Readline are closely coupled. Whenever
# Ncurses is built, build Readline, too.

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

if [[ -e "$INSTX_PKG_CACHE/ncurses" ]] && [[ -e "$INSTX_PKG_CACHE/readline" ]]; then
    echo ""
    echo "Ncurses and Readline already installed."
    exit 0
fi

###############################################################################

# Rebuild them as a pair
rm -rf "$INSTX_PKG_CACHE/ncurses"
rm -rf "$INSTX_PKG_CACHE/readline"

###############################################################################

if ! ./build-ncurses.sh
then
	echo "Failed to build Ncurses"
	exit 1
fi

###############################################################################

if ! ./build-readline.sh
then
    echo "Failed to build Readline"
    exit 1
fi

exit 0
