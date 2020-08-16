#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script converts LD_LIBRARY_PATH to DYLD_LIBRARY_PATH
# for OS X. Autotools authors don't need to worry about it.

echo ""
echo "**********************"
echo "Fixing LD_LIBRARY_PATH"
echo "**********************"

if [[ "$IS_DARWIN" -ne 0 ]]
then
    grep -rl LD_LIBRARY_PATH . | cut -f 1 -d ':' | sort | uniq | while IFS='' read -r file
    do
        # Display filename, strip leading "./"
        echo "patching ${file}..."

        touch -a -m -r "$file" "$file.timestamp"
        chmod a+w "$file"
        sed 's/LD_LIBRARY_PATH/DYLD_LIBRARY_PATH/g' "$file" > "$file.fixed"

        chmod go-w "$file"
        touch -a -m -r "$file.timestamp" "$file"
        rm "$file.timestamp"

    done
fi

exit 0
