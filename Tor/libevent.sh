#!/bin/bash

# We need gettext to build libevent
# This extends the path to look in some common locations (for example, if installed via Homebrew)
PATH=$PATH:/usr/local/bin:/usr/local/opt/gettext/bin

# Generate the configure script (necessary for version control distributions)
if [[ ! -f ./configure ]]; then
    ./autogen.sh
fi

REBUILD=0

# If the built binaries include a different set of architectures, then rebuild the target
if [[ ${ACTION:-build} = "build" ]]; then
    for LIBRARY in "${BUILT_PRODUCTS_DIR}/libevent"*.a
    do
        for ARCH in $ARCHS
        do
            if [[ $(lipo -info "${LIBRARY}" 2>&1) != *"${ARCH}"* ]]; then
                REBUILD=1;
            fi
        done
    done
fi

# If rebuilding or cleaning then delete the built products
if [[ $ACTION = "clean" ]] || [[ $REBUILD = 1 ]]; then
    rm "${BUILT_PRODUCTS_DIR}/libevent"*.a 2>/dev/null
fi

if [[ $REBUILD = 0 ]]; then
    exit;
fi

if [[ "${ENABLE_BITCODE}" = "YES" ]]; then
    BITCODE_FLAGS="-fembed-bitcode"
fi

# We need XPC to build libevent, so copy it from the OSX SDK into a temporary directory
XPC_INCLUDE_DIR="${CONFIGURATION_TEMP_DIR}/libevent-xpc"
mkdir -p "${XPC_INCLUDE_DIR}/xpc"
cp -f "$(xcrun --sdk macosx --show-sdk-path)/usr/include/xpc/base.h" "${XPC_INCLUDE_DIR}/xpc"

# Build each architecture one by one using clang
for ARCH in $ARCHS
do
    HOST=$(xcrun --sdk ${PLATFORM_NAME} clang -arch ${ARCH} -v 2>&1 | grep Target | sed -e 's/Target: //')
    PREFIX="${CONFIGURATION_TEMP_DIR}/libevent-${ARCH}"
    mkdir -p $PREFIX
    ./configure --disable-shared --enable-static --disable-debug-mode --host=${HOST} --prefix=${PREFIX} CFLAGS="${OTHER_CFLAGS} ${BITCODE_FLAGS} -I${XPC_INCLUDE_DIR} -arch ${ARCH}" CPPFLAGS="${OTHER_CFLAGS} ${BITCODE_FLAGS} -I${XPC_INCLUDE_DIR} -arch ${ARCH}" LDFLAGS="${OTHER_LDFLAGS} ${BITCODE_FLAGS}"
    make -j$(sysctl hw.ncpu | awk '{print $2}')
    make install
    mv include/event2/event-config.h "${PREFIX}/event-config.h"
    make distclean
    mv "${PREFIX}/event-config.h" include/event2/event-config.h
done

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Copy the build products from the temporary directory to the built products directory
for ARCH in $ARCHS
do
    for LIBRARY in "${CONFIGURATION_TEMP_DIR}/libevent-${ARCH}/lib/"*.a;
    do
        cp $LIBRARY "${BUILT_PRODUCTS_DIR}/$(basename ${LIBRARY} .a).${ARCH}.a"
    done
done

# Combine the built products into a fat binary
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libevent."*.a -output "${BUILT_PRODUCTS_DIR}/libevent.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libevent_core."*.a -output "${BUILT_PRODUCTS_DIR}/libevent_core.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libevent_pthreads."*.a -output "${BUILT_PRODUCTS_DIR}/libevent_pthreads.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libevent_extra."*.a -output "${BUILT_PRODUCTS_DIR}/libevent_extra.a"
rm "${BUILT_PRODUCTS_DIR}/libevent"*.*.a
