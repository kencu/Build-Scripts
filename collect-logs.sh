#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script collects configuration and log files.

if [[ -z "$(command -v zip)" ]]
then
    echo "zip program is missing"
    exit 1
fi

echo ""
echo "**********************"
echo "Saving log files"
echo "**********************"

rm -f "config.log.zip" "../config.log.zip" "../../config.log.zip"
rm -f "test-suite.log.zip" "../test-suite.log.zip" "../../test-suite.log.zip"

# Collect all config.log files
IFS="" find . -name 'config.log' -print | while read -r file
do
    zip -9 "config.log.zip" "$file"
done

# Collect all test-suite.log files
IFS="" find . -name 'test*.log' -print | while read -r file
do
    zip -9 "test-suite.log.zip" "$file"
done

# And Emacs test logs
IFS="" find . -name '*-tests.log' -print | while read -r file
do
    zip -9 "test-suite.log.zip" "$file"
done

exit 0
