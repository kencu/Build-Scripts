#!/usr/bin/env bash

# Older sudo programs, like on OS X 10.5, lack -E option
# This script will remove the option for old systems.

IFS="" find "$PWD" -name '*.sh' -print | while read -r file
do
    # Don't fix this script
    if [[ "$file" == "fix-sudo.sh" ]]; then
        continue
    fi

	# 'cp -p' copies all permissions and timestamps
	# https://pubs.opengroup.org/onlinepubs/9699919799/utilities/cp.html
    chmod u+w "$file" && cp -p "$file" "$file.fixed"
    sed 's/sudo -E/sudo/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done

echo "The -E option has been removed from sudo. This may cause some unexpected"
echo "results, especially for packages that build stuff during 'sudo make"
echo "install'. For example, Perl will create a .cpan folder in the user's home"
echo "directory owned by root."
