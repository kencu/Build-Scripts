#!/usr/bin/env bash

dir="$1"

if [[ -z "$dir" ]]; then
	echo "Please specify a directory"
	exit 1
fi

IFS="" find "$dir" -executable -type f -print | while read -r file
do
	if [[ ! $(file -i "$file" | grep "application") ]]; then continue; fi

    echo "****************************************"
	echo "$file:"
    echo ""
	readelf -d "$file" | grep -E 'RPATH|RUNPATH' | sed 's/    //g' | sed 's/Library runpath://g'

done
echo "****************************************"

exit 0
