#!/usr/bin/env bash

# Older sudo programs, like on OS X 10.5, lack -E option
# This script will remove the option for old systems.

IFS="" find "$PWD" -name '*.sh' -print | while read -r file
do
    # Don't fix this script
    if [[ "$file" == "fix-sudo.sh" ]]; then
        continue
    fi

    chmod a+w "$file" && cp "$file" "$file.fixed"
    sed 's/sudo -E/sudo/g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file" && chmod go-w "$file"
done

echo "The -E option has been removed from sudo. This may cause some unexpected"
echo "results, especially for packages that build stuff during 'sudo make"
echo "install'. For example, Perl will create a .cpan folder in the user's home"
echo "directory owned by root."
