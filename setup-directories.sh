#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script creates directories in $prefix. A couple
# of the packages are braindead and create files instead
# of directories.

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_SET" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S mkdir -p "$INSTX_PREFIX/"{bin,sbin,etc,include,var,libexec,share,info,man}
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S mkdir -p "$INSTX_LIBDIR"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S mkdir -p "$INSTX_LIBDIR/pkgconfig"
else
    mkdir -p "$INSTX_PREFIX/"{bin,sbin,etc,include,var,libexec,share,info,man}
    mkdir -p "$INSTX_LIBDIR"
    mkdir -p "$INSTX_LIBDIR/pkgconfig"
fi

exit 0
