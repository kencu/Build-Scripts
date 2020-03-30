#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script prompts for credentials for other scripts to use

# AIX lacks sudo. Only prompt if SUDO_PASSWORD_SET is not set in the environment.
# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
if [[ $(command -v sudo 2>/dev/null) ]] && [[ -z "${SUDO_PASSWORD_SET+x}" ]]
then

    # Some sudo are too old and can't handle -E option. Check for it now.
    # https://www.sudo.ws/pipermail/sudo-users/2020-March/006327.html
    count=$(sudo -E -h 2>&1 | grep -i -c illegal)
    if [ "$count" -ne 0 ]
    then
        # sudo does not accept -E
        count=$(grep -i -c 'sudo -E' build-bc.sh)
        if [ "$count" -ne 0 ]
        then
            printf ""
            printf "Sudo is too old. Please run fix-sudo.sh"
            [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
        fi
    fi

    printf ""
    printf "If you enter a sudo password, then it will be used for installation."
    printf "If you don't enter a password, then ensure INSTX_PREFIX is writable."
    printf "To avoid sudo and the password, just press ENTER and it won't be used."
    printf ""

    IFS="" read -r -s -p "Please enter password for sudo: " SUDO_PASSWORD
    printf "\n"

    # Smoke test the password
    if [[ -n "$SUDO_PASSWORD" ]]
    then
        # Attempt to drop the cached authentication, if present.
        # The -k option is not ubiquitous. It may fail.
        printf "" | sudo -kS >/dev/null 2>&1

        # Now, test the password
        if printf "%s\n" "$SUDO_PASSWORD" | sudo -S ls >/dev/null 2>&1;
        then
            printf "The sudo password appears correct"
        else
            printf "The sudo password appears incorrect"
            [[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
        fi
    else
        printf "The sudo password was not provided"
    fi

    # I would like to avoid exporting this...
    export SUDO_PASSWORD

    # Don't prompt for future passwords
    export SUDO_PASSWORD_SET=yes
fi

[[ "$0" == "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
