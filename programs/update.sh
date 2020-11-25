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

# Not correct:
#   wget -O root-anchors.p7s https://data.iana.org/root-anchors/root-anchors.p7s
#   openssl pkcs7 -print_certs -in root-anchors.p7s -inform DER -out root-anchors.pem
#   sed -i -e 's/^subject/#subject/g' -e 's/^issuer/#issuer/g' root-anchors.pem

UNBOUND_ANCHOR=$(command -v unbound-anchor)
if [ -z "$UNBOUND_ANCHOR" ]; then UNBOUND_ANCHOR=/sbin/unbound-anchor; fi

if [[ $(ls "$UNBOUND_ANCHOR" 2>/dev/null) ]]
then
	echo "Updating bootstrap rootkey.pem"
	"${UNBOUND_ANCHOR}" -a ../bootstrap/rootkey.pem -u data.iana.org
else
    echo "Failed to update bootstrap rootkey.pem. Install unbound-anchor"
    exit 1
fi

exit 0
