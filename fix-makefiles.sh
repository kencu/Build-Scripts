#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes $ORIGIN-based runpaths in Makefiles. Projects that
# generate makefiles on the fly after configure may break due to their
# cleverness. Also see https://github.com/Perl/perl5/issues/17978 and
# https://gitlab.alpinelinux.org/alpine/aports/-/issues/11655.

echo "**********************"
echo "Fixing Makefiles"
echo "**********************"

# We want the leading single quote, and the trailing slash.
origin1=$(echo "'"'$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
origin2=$(echo "'"'$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')

# And with braces
origin1b=$(echo "'"'${ORIGIN}/' | sed -e 's/[\/&]/\\&/g')
origin2b=$(echo "'"'$${ORIGIN}/' | sed -e 's/[\/&]/\\&/g')

(IFS="" find "./" -iname 'Makefile' -print | while read -r file
do
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1b/$origin2b/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
        "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    echo "$file" | sed 's/^\.\///g'
done)

(IFS="" find "./" -iname 'GNUmakefile' -print | while read -r file
do
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1b/$origin2b/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
           "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    echo "$file" | sed 's/^\.\///g'
done)

# This is for Nettle. Nettle is special.
(IFS="" find "./" -iname 'config.make' -print | while read -r file
do
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1b/$origin2b/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
           "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    echo "$file" | sed 's/^\.\///g'
done)

exit 0
