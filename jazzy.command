#!/bin/sh
CWD="$(pwd)"
MY_SCRIPT_PATH=`dirname "${BASH_SOURCE[0]}"`
cd "${MY_SCRIPT_PATH}"

echo "Creating Docs for the BigJuJuMap Framework\n"
rm -drf docs/*

jazzy \
  --readme ./README.md \
  --module BigJuJuMap \
  --xcodebuild-arguments -project,BigJuJuMap.xcodeproj,-scheme,BigJuJuMap,-destination,generic/platform=iOS,CODE_SIGNING_ALLOWED=NO,CODE_SIGNING_REQUIRED=NO,CODE_SIGN_IDENTITY= \
  --github_url https://github.com/LittleGreenViper/BigJuJuMap \
  --title "BigJuJuMap Documentation" \
  --min_acl public \
  --theme fullwidth
cp ./icon.png docs/
