#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script adds .libs/ to LD_LIBRARY_PATH and DYLD_LIBRARY_PATH
# It is needed by some packages on some of the BSDs to put the
# libraries on-path during testing.

LD_LIBRARY_PATH="$PWD/.libs:$LD_LIBRARY_PATH"
LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | sed 's|:$||')
export LD_LIBRARY_PATH

DYLD_LIBRARY_PATH="$PWD/.libs:$DYLD_LIBRARY_PATH"
DYLD_LIBRARY_PATH=$(echo "$DYLD_LIBRARY_PATH" | sed 's|:$||')
export DYLD_LIBRARY_PATH
