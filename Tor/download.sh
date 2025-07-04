#!/bin/sh

VERSION=$1

cd Tor/Assets

# Test if file is older then 1 week.
OLD="$(find geoip -mmin +10080 2>/dev/null)"

# Only download, if files are not existing or older than 1 week.
if [ ! -f geoip -o ! -z "$OLD" ]; then
    wget --output-document=geoip https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip
    wget --output-document=geoip6 https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip6
fi

cd ../..

# Test if folder is older then 1 week.
OLD="$(find tor.xcframework -mmin +10080 2>/dev/null)"

if [ ! -d tor.xcframework -o ! -z "$OLD" ]; then
    wget "https://github.com/iCepa/Tor.framework/releases/download/$VERSION/tor.xcframework.zip"
    unzip tor.xcframework.zip
    rm tor.xcframework.zip
fi

# Test if folder is older then 1 week.
OLD="$(find tor-nolzma.xcframework -mmin +10080 2>/dev/null)"

if [ ! -d tor-nolzma.xcframework -o ! -z "$OLD" ]; then
    wget "https://github.com/iCepa/Tor.framework/releases/download/$VERSION/tor-nolzma.xcframework.zip"
    unzip tor-nolzma.xcframework.zip
    rm tor-nolzma.xcframework.zip
fi
