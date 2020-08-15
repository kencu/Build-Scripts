#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes $ORIGIN-based runpaths in Makefiles. Projects that
# generate makefiles on the fly after configure may break due to their
# cleverness. Also see https://github.com/Perl/perl5/issues/17978 and
# https://gitlab.alpinelinux.org/alpine/aports/-/issues/11655.
#
# Perl's build system is completely broken beyond repair. The broken
# runpath handling cannot be fixed with makefile patching. Also see
# https://github.com/Perl/perl5/issues/17978.

echo ""
echo "**********************"
echo "Fixing Makefiles"
echo "**********************"

# We want the leading single quote, and the trailing slash.
origin1=$(echo "'"'$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
origin2=$(echo "'"'$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')

# And with braces
origin1b=$(echo "'"'${ORIGIN}/' | sed -e 's/[\/&]/\\&/g')
origin2b=$(echo "'"'$${ORIGIN}/' | sed -e 's/[\/&]/\\&/g')

IFS="" find "./" -iname 'Makefile' -print | while read -r file
do
    echo "$file" | sed 's/^\.\///g'

    touch -a -m -r "$file" "$file.timestamp.saved"
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1b/$origin2b/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
        "$file" > "$file.fixed" && \
    mv "$file.fixed" "$file"
    chmod go-w "$file"
    touch -a -m -r "$file.timestamp.saved" "$file"
    rm "$file.timestamp.saved"
done

IFS="" find "./" -iname 'GNUmakefile' -print | while read -r file
do
    echo "$file" | sed 's/^\.\///g'

    touch -a -m -r "$file" "$file.timestamp.saved"
    chmod a+w "$file"
    sed -e "s/$origin1/$origin2/g" \
        -e "s/$origin1b/$origin2b/g" \
        -e "s/GZIP_ENV = --best/GZIP_ENV = -9/g" \
        "$file" > "$file.fixed" && \
    mv "$file.fixed" "$file"
    chmod go-w "$file"
    touch -a -m -r "$file.timestamp.saved" "$file"
    rm "$file.timestamp.saved"
done

exit 0
