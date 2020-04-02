#!/usr/bin/env bash

# Older sudo programs, like on OS X 10.5, lack -E option
# This script will remove the option for old systems.

(IFS="" find "$PWD" -name '*.sh' -print | while read -r file
do
    # Don't dix this script
    if [ "$file" = "fix-sudo.sh" ]; then
        continue
    fi

	# 'cp -p' copies all permissions and timestamps
	# https://pubs.opengroup.org/onlinepubs/9699919799/utilities/cp.html
    chmod u+w "$file" && cp -p "$file" "$file.fixed"
    sed 's/sudo -E/sudo/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

echo "The -E option has been removed from sudo. This may cause some"
echo "unexpected results, especially for packages that build stuff"
echo "during 'sudo make install'. For example, Perl will create a"
echo ".cpan folder in the user's home directory owned by root."
