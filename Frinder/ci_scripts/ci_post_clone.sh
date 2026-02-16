#!/bin/sh
set -e

# Write GoogleService-Info.plist from Xcode Cloud environment variable
echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > "$CI_PRIMARY_REPOSITORY_PATH/Frinder/Frinder/GoogleService-Info.plist"

# Auto-increment build number using Xcode Cloud's build number
cd "$CI_PRIMARY_REPOSITORY_PATH/Frinder"
agvtool new-version -all "$CI_BUILD_NUMBER"
