#!/bin/sh

VERSION=$1

load() {
    curl --remote-name --progress-bar --location $1
}

cd Tor/Assets

# Test if file is older then 1 week.
OLD="$(find geoip -mmin +10080 2>/dev/null)"

# Only download, if files are not existing or older than 1 week.
if [ ! -f geoip -o ! -z "$OLD" ]; then
    load https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip
    load https://gitlab.torproject.org/tpo/core/tor/-/raw/main/src/config/geoip6
fi

cd ../..

for name in "tor" "tor-nolzma"
do
    # Test if folder is older then 1 week.
    OLD="$(find "$name.xcframework" -mmin +10080 2>/dev/null)"

    if [ ! -d "$name.xcframework" -o ! -z "$OLD" ]; then
        load "https://github.com/iCepa/Tor.framework/releases/download/$VERSION/$name.xcframework.zip"
        unzip "$name.xcframework.zip"
        rm "$name.xcframework.zip"
    fi
done
