#!/bin/sh
CWD="$(pwd)"
MY_SCRIPT_PATH=`dirname "${BASH_SOURCE[0]}"`
cd "${MY_SCRIPT_PATH}"

echo "Creating Docs for the BigJuJuMap Framework\n"
rm -drf docs/*

jazzy  --readme ./README.md \
       --build-tool-arguments -scheme,"Framework",-target,"BigJuJuMap" \
       --github_url https://github.com/LittleGreenViper/BigJuJuMap \
       --title "BigJuJuMap Doumentation" \
       --min_acl public \
       --theme fullwidth
cp ./icon.png docs/
