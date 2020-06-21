#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes $ORIGIN-based runpaths in Makefiles. Projects that generate
# makefiles on the fly after configure may break due to their cleverness.
# Also see https://gitlab.alpinelinux.org/alpine/aports/-/issues/11655

echo "**********************"
echo "Fixing Makefiles"
echo "**********************"

origin1=$(echo '$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
origin2=$(echo '$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
origin3=$(echo '$$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
origin4=$(echo '$$$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')

(IFS="" find "./" -iname 'Makefile' -print | while read -r file
do
    sed -e "s/$origin1/$origin2/g" \
        "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    echo "${file#"./"}"
done)

(IFS="" find "./" -iname 'GNUmakefile' -print | while read -r file
do
    sed -e "s/$origin1/$origin2/g" \
           "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    echo "${file#"./"}"
done)

exit 0
