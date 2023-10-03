#!/usr/bin/env sh

# Get absolute path to this script.
SCRIPTDIR=$(cd `dirname $0` && pwd)
WORKDIR="$SCRIPTDIR/onionmasq"
FILENAME="libonionmasq_apple.a"


# Assume we're in Xcode, which means we're probably cross-compiling.
# In this case, we need to add an extra library search path for build scripts and proc-macros,
# which run on the host instead of the target.
# (macOS Big Sur does not have linkable libraries in /usr/lib/.)
export LIBRARY_PATH="${SDKROOT}/usr/lib:${LIBRARY_PATH:-}"

# The $PATH used by Xcode likely won't contain Cargo, fix that.
# This assumes a default `rustup` setup.
export PATH="$HOME/.cargo/bin:$PATH"


cd "$WORKDIR"

# NOTE: This won't be executed, when this script is set up as a "build phase script".
# There seems no way to configure CocoaPods to make this run as a target script,
# where it would be executed.
# However, this is here for documentary purposes and in case you want to set
# this manually as an "external target" script.
# See https://kelan.io/2009/run-script-while-cleaning-in-xcode/
if [ "$ACTION" = "clean" ]; then
    make clean

    exit 0
fi

export MACOSX_DEPLOYMENT_TARGET=10.13

CONF_LOWER="$(echo $CONFIGURATION | tr '[:upper:]' '[:lower:]')"

if [ "${PLATFORM_NAME:-iphoneos}" = "macosx" ]; then
    if [ "${CONF_LOWER:-debug}" = "release" ]; then
        TARGET_PLATFORM="universal-macos"

        make "macos-${CONF_LOWER}"
    else
        if [ "${ARCHS:-x86}" = "arm64" ]; then
            TARGET_PLATFORM="aarch64-apple-darwin"
        else
            TARGET_PLATFORM="x86_64-apple-darwin"
        fi

        make "macos-verbose-${TARGET_PLATFORM}"
    fi

elif [ "${PLATFORM_NAME:-iphoneos}" = "iphonesimulator" ]; then
    if [ "${ARCHS:-x86}" = "arm64" ]; then
        TARGET_PLATFORM="aarch64-apple-ios-sim"
    else
        TARGET_PLATFORM="x86_64-apple-ios"
    fi

    make "ios-${CONF_LOWER}-${TARGET_PLATFORM}"
else
    TARGET_PLATFORM="aarch64-apple-ios"

    make "ios-${CONF_LOWER}-${TARGET_PLATFORM}"
fi


SOURCE="${WORKDIR}/target/${TARGET_PLATFORM}/${CONF_LOWER}/${FILENAME}"

if [ -e "${SOURCE}" ]; then
    echo "Link '${SOURCE}' to '${BUILT_PRODUCTS_DIR}'"

    rm -f "${BUILT_PRODUCTS_DIR}/${FILENAME}"

    ln -s "${SOURCE}" "${BUILT_PRODUCTS_DIR}"
fi
