#!/usr/bin/env bash

# Older sudo programs, like on OS X 10.5, lack -E option
# This script will remove the option for old systems.

(IFS="" find "$PWD" -name '*.sh' -print | while read -r file
do
    # Don't dix this script
    if [ "$file" = "fix-sudo.sh" ]; then
        continue
    fi

    chmod a+w "$file"
    cp -p "$file" "$file.fixed"
    sed 's/sudo -E/sudo/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod a+x "$file" && chmod o-w "$file"
done)
