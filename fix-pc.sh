#!/usr/bin/env bash

# This script fixes *.pc files. It removes extra fodder rom Libs and
# Libs.private. It is needed because some configure scripts cannot
# handle the extra options in pkg config files. For example, Zile
# fails to find Ncurses because Ncurses uses the following in its
# *.pc file:
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

if ! "${CXX}" "$PROG_PATH/fix-pc.cpp" -o fix-pc.exe;
then
    echo "Failed to build fix-pc"
    exit 1
fi

(IFS="" find "$PWD" -iname '*.pc' -print | while read -r file
do
    echo "Fixing $file..."
    cp -p "$file" "$file.fixed"
    ./fix-pc.exe "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
done)

exit 0
