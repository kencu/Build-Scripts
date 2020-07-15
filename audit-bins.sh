#!/usr/bin/env bash

dir="$1"

if [[ -z "$dir" ]]; then
    echo "Please specify a directory"
    exit 1
fi

# Find a non-anemic grep
GREP=$(command -v grep 2>/dev/null)
if [[ -d /usr/gnu/bin ]]; then
    GREP=/usr/gnu/bin/grep
fi

# Find someprog files using the shell wildcard. Some programs
# are _not_ executable and get missed in the do loop.
IFS="" find "$dir" -name '*' -print | while read -r file
do
    if [[ ! $(file -i "$file" | $GREP -E "regular|application") ]]; then continue; fi

    echo "****************************************"
    echo "$file:"
    echo ""

    if [[ $(command -v readelf 2>/dev/null) ]]; then
        readelf -d "$file" | $GREP -E 'RPATH|RUNPATH' | sed 's/  */ /g' | cut -d ' ' -f 3,6
    elif [[ $(command -v otool 2>/dev/null) ]]; then
        otool -l "$file" | $GREP -E 'RPATH|RUNPATH' | sed 's/  */ /g' | cut -d ' ' -f 3,5
    elif [[ $(command -v elfdump 2>/dev/null) ]]; then
        elfdump "$file" | $GREP -E 'RPATH|RUNPATH' | sed 's/  */ /g' | cut -d ' ' -f 3,5
    fi

done
echo "****************************************"

exit 0
