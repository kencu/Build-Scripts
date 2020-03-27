#!/usr/bin/env bash

# Older sudo programs, like on OS X 10.5, lack -E option
# This script will remove the option for old systems.

sed -i 's/sudo -E/sudo/g' *.sh
