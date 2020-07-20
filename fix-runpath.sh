#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script attempts to fix runpaths. Perl, OpenLDAP, Nettle and
# several others need a full fix because they don't escape the dollar
# sign or they expand the rpath token. Also see
# https://github.com/Perl/perl5/issues/17534.
# Many GNU libraries need the runpaths fixed because the order gets
# randomized during configuration. This script should be run after
# 'make' and before 'make check'. Finally, the latest patchelf is
# needed due to mishandling something in patchelf.
# Also see https://bugzilla.redhat.com/show_bug.cgi?id=1497012 and
# https://bugs.launchpad.net/ubuntu/+source/patchelf/+bug/1888175

echo "**********************"
echo "Fixing runpaths"
echo "**********************"

###############################################################################

# Verify system uses ELF
magic=$(cut -b 2-4 /bin/ls | head -n 1)
if [[ "$magic" != "ELF" ]]; then
    echo "Nothing to do; ELF is not used"
    exit 0
fi

###############################################################################

# Build a program to easily read magic bytes
if [[ -n "$1" ]]; then
    PROG_PATH="$1"
elif [[ -d "./programs" ]]; then
    PROG_PATH="./programs"
elif [[ -d "../programs" ]]; then
    PROG_PATH="../programs"
elif [[ -d "../../programs" ]]; then
    PROG_PATH="../../programs"
elif [[ -d "../../../programs" ]]; then
    PROG_PATH="../../../programs"
fi

CC="${CC:-cc}"
if ! "${CC}" "$PROG_PATH/file-magic.c" -o file-magic.exe 2>/dev/null;
then
    if ! gcc "$PROG_PATH/file-magic.c" -o file-magic.exe 2>/dev/null;
    then
        if ! clang "$PROG_PATH/file-magic.c" -o file-magic.exe 2>/dev/null;
        then
            echo "Failed to build file-magic"
            exit 1
        fi
    fi
fi

###############################################################################

# We need to remove the single quotes.
THIS_RUNPATH="$INSTX_OPATH:$INSTX_RPATH"
THIS_RUNPATH="""$(echo "$THIS_RUNPATH" | sed "s/'//g")"""
echo "Using RUNPATH \"$THIS_RUNPATH\""

# Find a non-anemic grep
GREP=$(command -v grep 2>/dev/null)
if [[ -d /usr/gnu/bin ]]; then
    GREP=/usr/gnu/bin/grep
fi

IS_SOLARIS=$(uname -s | $GREP -i -c 'sunos')

# Find programs and libraries using the shell wildcard. Some programs
# and libraries are _not_ executable and get missed in the do loop
# when using options like -executable.
IFS="" find "./" -type f -name '*' -print | while read -r file
do
    # Quick smoke test. Object files have ELF signature.
    if [[ $(echo "$file" | $GREP -E '\.o$') ]]; then continue; fi

    # Check for ELF signature
    magic=$(./file-magic.exe "$file")
    if [[ "$magic" != "7F454C46" ]]; then continue; fi

    echo "$file" | sed 's/^\.\///g'

    touch -a -m -r "$file" "file.timestamp"
    chmod a+w "$file"

    # https://blogs.oracle.com/solaris/avoiding-ldlibrarypath%3a-the-options-v2
    if [[ "$IS_SOLARIS" -ne 0 && -e /usr/bin/elfedit ]]
    then
        /usr/bin/elfedit -e "dyn:rpath $THIS_RUNPATH" "$file"
        /usr/bin/elfedit -e "dyn:runpath $THIS_RUNPATH" "$file"

    # https://stackoverflow.com/questions/13769141/can-i-change-rpath-in-an-already-compiled-binary
    elif [[ -n $(command -v patchelf 2>/dev/null) ]]
    then
        #echo "  Before: $(readelf -d "$file" | grep PATH)"
        patchelf --set-rpath "$THIS_RUNPATH" "$file"
        #echo "  After: $(readelf -d "$file" | grep PATH)"

    elif [[ -n $(command -v chrpath 2>/dev/null) ]]
    then
        chrpath -r "$THIS_RUNPATH" "$file" 2>/dev/null

    else
        echo "Unable to find elf editor"
    fi

    chmod go-w "$file"
    touch -a -m -r "file.timestamp" "$file"

done

exit 0
