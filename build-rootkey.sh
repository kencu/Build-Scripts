#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script writes several files needed by DNSSEC
# and libraries like Unbound and LDNS.

PKG_NAME=rootkey

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

# Perform this action automatically for the user. setup-cacert.sh writes the
# certs locally for the user so we can download cacerts.pem from cURL.
# build-cacert.sh installs cacerts.pem in ${OPT_CACERT_PATH}. Programs like
# cURL, Git and Wget use cacerts.pem.
if [[ ! -f "$HOME/.build-scripts/cacert/cacert.pem" ]]; then
    # Hide output to cut down on noise.
    ./setup-cacerts.sh &>/dev/null
fi

if [[ -e "$INSTX_PKG_CACHE/$PKG_NAME" ]]; then
    #echo ""
    #echo "$PKG_NAME is already installed."
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

# Determine user:group owners

if [[ -d /private/etc ]]
then
    ROOT_USR=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $4}')
else
    ROOT_USR=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $4}')
fi

###############################################################################

echo ""
echo "========================================"
echo "============ ICANN Root CAs ============"
echo "========================================"

BOOTSTRAP_ICANN_FILE="bootstrap/icannbundle.pem"

if [[ -n "$SUDO_PASSWORD" ]]
then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S mkdir -p "$OPT_UNBOUND_ICANN_PATH"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S cp "$BOOTSTRAP_ICANN_FILE" "$OPT_UNBOUND_ICANN_FILE"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chown "$ROOT_USR":"$ROOT_GRP" "$OPT_UNBOUND_ICANN_PATH"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chmod 644 "$OPT_UNBOUND_ICANN_FILE"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chown "$ROOT_USR":"$ROOT_GRP" "$OPT_UNBOUND_ICANN_FILE"
else
    mkdir -p "$OPT_UNBOUND_ICANN_PATH"
    cp "$BOOTSTRAP_ICANN_FILE" "$OPT_UNBOUND_ICANN_FILE"
    chmod 644 "$OPT_UNBOUND_ICANN_FILE"
fi

###############################################################################

echo ""
echo "========================================"
echo "============ DNS Root Keys ============="
echo "========================================"

BOOTSTRAP_ROOTKEY_FILE="bootstrap/rootkey.pem"

if [[ -n "$SUDO_PASSWORD" ]]
then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S mkdir -p "$OPT_UNBOUND_ROOTKEY_PATH"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S cp "$BOOTSTRAP_ROOTKEY_FILE" "$OPT_UNBOUND_ROOTKEY_FILE"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chown "$ROOT_USR":"$ROOT_GRP" "$OPT_UNBOUND_ROOTKEY_PATH"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chmod 644 "$OPT_UNBOUND_ROOTKEY_FILE"
    printf "%s\n" "$SUDO_PASSWORD" | sudo -E -S chown "$ROOT_USR":"$ROOT_GRP" "$OPT_UNBOUND_ROOTKEY_FILE"
else
    mkdir -p "$OPT_UNBOUND_ROOTKEY_PATH"
    cp "$BOOTSTRAP_ROOTKEY_FILE" "$OPT_UNBOUND_ROOTKEY_FILE"
    chmod 644 "$OPT_UNBOUND_ROOTKEY_FILE"
fi

###############################################################################

echo ""
echo "*****************************************************************************"
echo "You should create a cron job that runs unbound-anchor on a"
echo "regular basis to update $OPT_UNBOUND_ROOTKEY_FILE"
echo "*****************************************************************************"
echo ""

###############################################################################

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PKG_CACHE/$PKG_NAME"

exit 0
