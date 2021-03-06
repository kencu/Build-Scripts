#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Wget and OpenSSL from sources.

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

cd "bootstrap" || exit 1

if ! ./bootstrap-wget.sh; then
    echo "Bootstrap failed for Wget"
    exit 1
fi

# Remove old boostrap dir
rm -rf "$HOME/bootstrap"

exit 0
