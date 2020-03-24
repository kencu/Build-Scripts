#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script converts LD_LIBRARY_PATH to DYLD_LIBRARY_PATH
# for OS X. Autotools authors don't need to worry about it.

if [[ "$IS_DARWIN" -ne 0 ]]
then
    grep -rl LD_LIBRARY_PATH . | cut -f 1 -d ':' | sort | uniq | while IFS='' read -r file
    do
        echo "patching $file..."
        cp -p "$file" "$file.fixed"
        sed 's/LD_LIBRARY_PATH/DYLD_LIBRARY_PATH/g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
    done
fi

exit 0
