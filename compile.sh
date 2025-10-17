#!/usr/bin/env bash

# compile script
osacompile -l JavaScript -o 'sub metadata.app' 'sub metadata.js'
# replace icon
cp icon/sub.icns 'sub metadata.app'/Contents/Resources/applet.icns
# update app so icon shows
touch 'sub metadata.app'
