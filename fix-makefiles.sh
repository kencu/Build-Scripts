#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes $ORIGIN-based runpaths in Makefiles.
# Projects that generate makefiles on the fly after
# configure may break due to their cleverness.

echo "**********************"
echo "Fixing Makefiles"
echo "**********************"

old_origin=$(echo '$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
new_origin=$(echo '$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
(IFS="" find "$PWD" -iname 'Makefile' -print | while read -r file
do
    sed -e "s/$old_origin/$new_origin/g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

old_origin=$(echo '$$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
new_origin=$(echo '$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
(IFS="" find "$PWD" -iname 'Makefile' -print | while read -r file
do
    sed -e "s/$old_origin/$new_origin/g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

old_origin=$(echo '$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
new_origin=$(echo '$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
(IFS="" find "$PWD" -iname 'GNUmakefile' -print | while read -r file
do
    sed -e "s/$old_origin/$new_origin/g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

old_origin=$(echo '$$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
new_origin=$(echo '$$ORIGIN/' | sed -e 's/[\/&]/\\&/g')
(IFS="" find "$PWD" -iname 'GNUmakefile' -print | while read -r file
do
    sed -e "s/$old_origin/$new_origin/g" "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

exit 0
