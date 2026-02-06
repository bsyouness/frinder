#!/bin/sh
set -e

# Write GoogleService-Info.plist from Xcode Cloud environment variable
echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > "$CI_PRIMARY_REPOSITORY_PATH/Frinder/Frinder/GoogleService-Info.plist"
