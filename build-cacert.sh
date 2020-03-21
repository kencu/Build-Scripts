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
trap finish EXIT

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
# installs cacerts.pem in ${SH_CACERT_PATH}. Programs like
# cURL, Git and Wget use cacerts.pem.
if [[ ! -f "$HOME/.build-scripts/cacert/cacert.pem" ]]; then
    # Hide output to cut down on noise.
    ./setup-cacerts.sh &>/dev/null
fi

if [[ -e "$INSTX_PACKAGE_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    #echo ""
    #echo "$PKG_NAME is already installed."
    exit 0
fi

###############################################################################

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_SET" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

# Most systems will use Wget. Some OS X machines will use cURL
CACERT_FILE=$(basename "$SH_CACERT_FILE")

if [[ -n $(command -v "$WGET" 2>/dev/null) ]]
then
	if ! "$WGET" -O "$CACERT_FILE" --ca-certificate="$GLOBALSIGN_ROOT" \
		 "https://curl.haxx.se/ca/cacert.pem"
	then
		echo "Failed to download $CACERT_FILE"
		exit 1
	fi
else
	if ! curl -L -o "$CACERT_FILE" --cacert "$GLOBALSIGN_ROOT" \
		 "https://curl.haxx.se/ca/cacert.pem"
	then
		echo "Failed to download $CACERT_FILE"
		exit 1
	fi
fi

if [[ -d /private/etc ]]
then
    ROOT_USR=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /private/etc | head -n 1 | awk 'NR==1 {print $4}')
else
    ROOT_USR=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $3}')
    ROOT_GRP=$(ls -ld /etc | head -n 1 | awk 'NR==1 {print $4}')
fi

if [[ -s "$CACERT_FILE" ]]
then
    if [[ -n "$SUDO_PASSWORD" ]]; then
        printf "%s\n" "$SUDO_PASSWORD" | sudo -kS mkdir -p "$SH_CACERT_PATH"
        printf "%s\n" "$SUDO_PASSWORD" | sudo -kS mv cacert.pem "$SH_CACERT_FILE"
        printf "%s\n" "$SUDO_PASSWORD" | sudo -kS chown "$ROOT_USR":"$ROOT_GRP" "$SH_CACERT_PATH"
        printf "%s\n" "$SUDO_PASSWORD" | sudo -kS chmod 644 "$SH_CACERT_FILE"
        printf "%s\n" "$SUDO_PASSWORD" | sudo -kS chown "$ROOT_USR":"$ROOT_GRP" "$SH_CACERT_FILE"
    else
        mkdir -p "$SH_CACERT_PATH"
        cp "$CACERT_FILE" "$SH_CACERT_FILE"
        chmod 644 "$SH_CACERT_FILE"
    fi
fi

###############################################################################

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PACKAGE_CACHE/$PKG_NAME"
echo ""

exit 0
