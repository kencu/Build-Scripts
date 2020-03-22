#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script fixes configure and configure.ac

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

###############################################################################

# Autoconf lib paths are wrong for Fedora and Solaris. Thanks NM.
# http://pkgs.fedoraproject.org/cgit/rpms/gnutls.git/tree/gnutls.spec;

# Fix "rm: conftest.dSYM: is a directory" on Darwin
# https://lists.gnu.org/archive/html/bug-autoconf/2007-11/msg00032.html
if [[ $(uname -s 2>&1 | grep -i -c 'darwin') -ne 0 ]]
then
    # Keep configure in the future
    (IFS="" find "$PWD" -iname 'configure' -print | while read -r file
    do
        chmod a+w "$file"
        cp -p "$file" "$file.fixed"
        sed 's/rm -f core/rm -rf core/g' "$file" > "$file.fixed"
        mv "$file.fixed" "$file"
        chmod a+x "$file" && chmod a-w "$file"
    done)
fi

echo "patching sys_lib_dlsearch_path_spec..."

# Keep configure in the future
(IFS="" find "$PWD" -iname 'configure' -print | while read -r file
do
    chmod a+w "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    chmod a+x "$file" && chmod a-w "$file"
done)

# And keep configure.ac in the past
(IFS="" find "$PWD" -iname 'configure.ac' -print | while read -r file
do
    chmod a+w "$file"
    cp -p "$file" "$file.fixed"
    sed -e 's|sys_lib_dlsearch_path_spec="/lib /usr/lib|sys_lib_dlsearch_path_spec="/lib %{_libdir} /usr/lib|g' "$file" > "$file.fixed"
    mv "$file.fixed" "$file"
    touch -t 197001010000 "$file"
done)

# Find the path to config.guess and config.sub, if not given on the command line
if [[ -n "$1" ]]; then
    PROG_PATH="$1"
elif [[ -d "./patch" ]]; then
    PROG_PATH="./patch"
elif [[ -d "../patch" ]]; then
    PROG_PATH="../patch"
elif [[ -d "../../patch" ]]; then
    PROG_PATH="../../patch"
elif [[ -d "../../../patch" ]]; then
    PROG_PATH="../../../patch"
fi

echo "patching config.sub..."
(IFS="" find "$PWD" -name 'config.sub' -print | while read -r file
do
    chmod a+w "$file"
    cp "$PROG_PATH/config.sub" "$file"
    chmod a-w "$file"; chmod a+x "$file"
done)

echo "patching config.guess..."
(IFS="" find "$PWD" -name 'config.guess' -print | while read -r file
do
    chmod a+w "$file"
    cp "$PROG_PATH/config.guess" "$file"
    chmod a-w "$file"; chmod a+x "$file"
done)

echo ""
