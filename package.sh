#!/bin/bash

# Name of the package
PACKAGE_NAME="org.user.pinterest"
OUTPUT_FILE="${PACKAGE_NAME}.plasmoid"

# Remove existing package if it exists
if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
fi

# Create the package
# We exclude the .git directory, the packaging script itself, and any temporary files
zip -r "$OUTPUT_FILE" . -x "*.git*" -x "package.sh" -x "*.DS_Store*" -x "*~" -x "*__pycache__*" -x "*.backup"

echo "Package created: $OUTPUT_FILE"
echo "You can install it using: kpackagetool6 -i $OUTPUT_FILE"
