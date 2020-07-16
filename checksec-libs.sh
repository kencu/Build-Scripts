#!/usr/bin/env bash

# Download and install checksec:
#   wget https://raw.githubusercontent.com/slimm609/checksec.sh/master/checksec
#   xattr -r -d com.apple.quarantine checksec
#   chmod a+x checksec
#   sudo mv checksec /usr/bin

dir="$1"

if [[ -z $(command -v checksec 2>/dev/null) ]]; then
    echo "Please install checksec"
    exit 1
fi

if [[ -z "$dir" ]]; then
    echo "Please specify a directory"
    exit 1
fi

# Find a non-anemic grep
GREP=$(command -v grep 2>/dev/null)
if [[ -d /usr/gnu/bin ]]; then
    GREP=/usr/gnu/bin/grep
fi

if [[ $(uname -s | $GREP Darwin) ]]; then
    LIB_EXT='*.dylib*'
else
    LIB_EXT='*.so*'
fi

# Find libfoo.so* files using the shell wildcard. Some libraries
# are _not_ executable and get missed in the do loop.
IFS="" find "$dir" -name "$LIB_EXT" -print | while read -r file
do
    if [[ ! $(file -i "$file" | $GREP -E "regular|application") ]]; then continue; fi

    echo "****************************************"
    echo "$file:"
    echo ""

    checksec --file="$file"

done
echo "****************************************"

exit 0
