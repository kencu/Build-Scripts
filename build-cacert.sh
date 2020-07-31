#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script writes several Root CA certifcates needed
# for other scripts and wget downloads over HTTPS.

PKG_NAME=cacert

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT INT

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

# Perform this action automatically for the user.
# setup-cacert.sh writes the certs locally for the user so
# we can download cacerts.pem from cURL. build-cacert.sh
# installs cacerts.pem in ${OPT_CACERT_PATH}. Programs like
# cURL, Git and Wget use cacerts.pem.
if [[ ! -e "$HOME/.build-scripts/cacert/cacert.pem" ]]; then
    # Hide output to cut down on noise.
    ./setup-cacerts.sh &>/dev/null
fi

# Line 4 is a date/time stamp
bootstrap_cacert=$(sed '4!d' "bootstrap/cacert.pem")
installed_cacert=$(sed '4!d' "$OPT_CACERT_FILE" 2>/dev/null)

# The bootstrap cacert.pem is the latest
if [[ "x$bootstrap_cacert" != "x$installed_cacert" ]]; then
    echo ""
    echo "Updating cacert.pem"
    echo "  installed: $(cut -f 2-5 -d ':' <<< $installed_cacert)"
    echo "  available: $(cut -f 2-5 -d ':' <<< $bootstrap_cacert)"
else
    #echo ""
    #echo "$PKG_NAME is already installed."
    exit 0
fi

###############################################################################

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_DONE" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if [[ -d /private/etc ]]
then
    ROOT_USR=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $4}')
else
    ROOT_USR=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $4}')
fi

CACERT_FILE="bootstrap/cacert.pem"

if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S mkdir -p "$OPT_CACERT_PATH"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S cp "$CACERT_FILE" "$OPT_CACERT_FILE"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chown "$ROOT_USR:$ROOT_GRP" "$OPT_CACERT_PATH"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chmod 644 "$OPT_CACERT_FILE"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chown "$ROOT_USR:$ROOT_GRP" "$OPT_CACERT_FILE"
else
    mkdir -p "$OPT_CACERT_PATH"
    cp "$CACERT_FILE" "$OPT_CACERT_FILE"
    chmod 644 "$OPT_CACERT_FILE"
fi

###############################################################################

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"
echo ""

exit 0
