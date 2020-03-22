#!/usr/bin/env bash

# This script fixes *.pc files. It removes extra fodder from Libs
# and Libs.private. It is needed because some configure scripts
# cannot handle the extra options in pkg config files. For example,
# Zile fails to find Ncurses because Ncurses uses the following in
# its *.pc file:
#     Libs: -L<path> -Wl,-rpath,<path> -lncurses -ltinfo
# Zile can find the libraries when using:
#     Libs: -L<path> -lncurses -ltinfo

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

: "${CXX:=CC}"
if ! "${CXX}" "$PROG_PATH/fix-pkgconfig.cpp" -o fix-pkgconfig.exe 2>/dev/null;
then
    if ! g++ "$PROG_PATH/fix-pkgconfig.cpp" -o fix-pkgconfig.exe 2>/dev/null;
    then
        if ! clang++ "$PROG_PATH/fix-pkgconfig.cpp" -o fix-pkgconfig.exe 2>/dev/null;
        then
            echo "Failed to build fix-pkgconfig"
            exit 1
        fi
    fi
fi

(IFS="" find . -iname '*.pc' -print | while read -r file
do
    echo "Patching $file..."
    cp -p "$file" "$file.fixed"
    touch -r "$file" "file.timestamp"
    ./fix-pkgconfig.exe "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    touch -r "file.timestamp" "$file"
done)

exit 0
