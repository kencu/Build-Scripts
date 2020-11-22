#!/usr/bin/env bash

echo "Updating config.guess and config.sub"
wget -q -O config.guess 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
wget -q -O config.sub 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'

if [[ -e config.guess ]]
then
    echo "Fixing config.guess permissions"
    chmod +x config.guess
    xattr -d com.apple.quarantine config.guess 2>/dev/null
fi

if [[ -e config.sub ]]
then
    echo "Fixing config.sub permissions"
    chmod +x config.sub
    xattr -d com.apple.quarantine config.sub 2>/dev/null
fi

echo "Updating bootstrap cacert.pem"
wget -q -O ../bootstrap/cacert.pem 'https://curl.haxx.se/ca/cacert.pem'

echo "Updating bootstrap icannbundle.pem"
wget -q -O ../bootstrap/icannbundle.pem 'https://data.iana.org/root-anchors/icannbundle.pem'

if [[ $(command -v unbound-anchor) ]]
then
	echo "Updating bootstrap rootkey.pem"
	/sbin/unbound-anchor -a rootkey.pem -u data.iana.org
else
    echo "Failed to update bootstrap rootkey.pem. Install unbound-anchor"
    exit 1
fi

exit 0
