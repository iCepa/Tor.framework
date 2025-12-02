#!/bin/sh

VERSION=$1
NAMES=$2
shift
checksums=( "$@" )

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

declare -i i=0

for name in $NAMES
do
    if [ ! -d "$name.xcframework" ]; then
        load "https://github.com/iCepa/Tor.framework/releases/download/$VERSION/$name.xcframework.zip"

        actual=$(shasum -a 256 "$name.xcframework.zip" | awk '{print $1}')

        if [ "$actual" != "${checksums[$i]}" ]; then
            echo "ERROR: Checksum verification failed: $actual != ${checksums[$i]}"

            exit 1
        fi

        unzip "$name.xcframework.zip"
        rm "$name.xcframework.zip"
    fi

    i+=1
done
