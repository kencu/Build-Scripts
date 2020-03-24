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

CXX="${CXX:-CC}"
if ! "${CXX}" "$PROG_PATH/fix-configure.cpp" -o fix-configure.exe 2>/dev/null;
then
    if ! g++ "$PROG_PATH/fix-configure.cpp" -o fix-configure.exe 2>/dev/null;
    then
        if ! clang++ "$PROG_PATH/fix-configure.cpp" -o fix-configure.exe 2>/dev/null;
        then
            echo "Failed to build fix-configure"
            exit 1
        fi
    fi
fi

(IFS="" find . -name 'configure.ac' -print | while read -r file
do
    echo "patching $file..."
    cp -p "$file" "$file.fixed"
    touch -a -m -r "$file" "file.timestamp"
    ./fix-configure.exe "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    touch -a -m -r "file.timestamp" "$file"
    touch -t 197001010000 "$file"
done)

(IFS="" find . -name 'configure' -print | while read -r file
do
    echo "patching $file..."
    cp -p "$file" "$file.fixed"
    touch -a -m -r "$file" "file.timestamp"
    ./fix-configure.exe "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    touch -a -m -r "file.timestamp" "$file"
done)

# Cleanup artifacts.
rm -f file.timestamp 2>/dev/null

echo "patching config.sub..."
(IFS="" find . -name 'config.sub' -print | while read -r file
do
    chmod a+w "$file"
    cp -p "$PROG_PATH/config.sub" "$file"
    chmod a-w "$file"
done)

echo "patching config.guess..."
(IFS="" find . -name 'config.guess' -print | while read -r file
do
    chmod a+w "$file"
    cp -p "$PROG_PATH/config.guess" "$file"
    chmod a-w "$file"
done)

echo ""

exit 0
