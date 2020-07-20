#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script attempts to fix runpaths. Perl, Nettle and several
# others need a full fix because they don't escape the dollar sign.
# Also see https://github.com/Perl/perl5/issues/17534.
# Many GNU libraries need the runpaths re-ordered because the order
# gets randomized during configuration. This script should be run
# after 'make' and before 'make check'. Finally, the latest patchelf
# is needed due to mishandling something in patchelf.
# Also see https://bugzilla.redhat.com/show_bug.cgi?id=1497012 and
# https://bugs.launchpad.net/ubuntu/+source/patchelf/+bug/1888175

###############################################################################

# Verify system uses ELF
magic=$(head -n 1 /bin/ls | cut -b 2-4)
if [[ "x$magic" != "xELF" ]]; then
    echo "Nothing to do; ELF is not used"
    exit 0
fi

###############################################################################

echo "**********************"
echo "Fixing runpaths"
echo "**********************"

# We need to remove the single quotes.
THIS_RUNPATH="$INSTX_OPATH:$INSTX_RPATH"
THIS_RUNPATH="""$(echo $THIS_RUNPATH | sed "s/'//g" | sed 's/\$/\\\$/g')"""

THIS_RUNPATH="""\$ORIGIN/../lib:/export/home/jwalton/tmp/ok2delete/lib"""
echo "Using \"$THIS_RUNPATH\""

# Find a non-anemic grep
GREP=$(command -v grep 2>/dev/null)
if [[ -d /usr/gnu/bin ]]; then
    GREP=/usr/gnu/bin/grep
fi

# Find find programs and libraries using the shell wildcard. Some programs
# and libraries are _not_ executable and get missed in the do loop.
IFS="" find "$PWD" -type f -name '*' -print | while read -r file
do
    # Quick smoke test. Object files have ELF signature.
    if [[ $(echo "$file" | $GREP -E '\.o$') ]]; then continue; fi

    # Check for ELF signature
    magic=$(head -n 1 "$file" | cut -b 2-4)
    if [[ "x$magic" != "xELF" ]]; then continue; fi
    # echo "$file" | sed 's/^\.\///g'
	echo "$file"

    chmod a+w "$file"

    # https://stackoverflow.com/questions/13769141/can-i-change-rpath-in-an-already-compiled-binary
    if [[ -n $(command -v patchelf 2>/dev/null) ]]
    then
        patchelf --set-rpath "$THIS_RUNPATH" "$file"
        # patchelf --set-rpath --force-rpath "$THIS_RUNPATH" "$file"

    # https://blogs.oracle.com/solaris/avoiding-ldlibrarypath%3a-the-options-v2
    elif [[ -n $(command -v elfedit 2>/dev/null) ]]
    then
        elfedit -e "dyn:rpath $THIS_RUNPATH" "$file"
        elfedit -e "dyn:runpath $THIS_RUNPATH" "$file"

    elif [[ -n $(command -v chrpath 2>/dev/null) ]]
    then
        chrpath -r "$THIS_RUNPATH" "$file" 2>/dev/null

    else
	    echo "Unable to find elf editor"
    fi

    chmod go-w "$file"
done

exit 0
