#!/usr/bin/env bash

dir="$1"

if [[ -z "$dir" ]]; then
    echo "Please specify a directory"
    exit 1
fi

# Find someprog files using the shell wildcard. Some programs
# are _not_ executable and get missed in the do loop.
IFS="" find "$dir" "*" -print | while read -r file
do
    if [[ ! $(file -i "$file" | grep -E "regular|application") ]]; then continue; fi

    echo "****************************************"
    echo "$file:"
    echo ""
    readelf -d "$file" | grep -E 'RPATH|RUNPATH' | cut -c 20- | sed 's/    //g' | sed 's/Library runpath://g'

done
echo "****************************************"

exit 0