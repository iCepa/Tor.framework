#!/bin/bash

# We need gettext to build tor
# This extends the path to look in some common locations (for example, if installed via Homebrew)
PATH=$PATH:/usr/local/bin:/usr/local/opt/gettext/bin

# Generate the configure script (necessary for version control distributions)
if [[ ! -f ./configure ]]; then
    ./autogen.sh
fi

REBUILD=0

# If the built binaries include a different set of architectures, then rebuild the target
if [[ ${ACTION:-build} = "build" ]]; then
    for LIBRARY in "${BUILT_PRODUCTS_DIR}/libtor.a" "${BUILT_PRODUCTS_DIR}/libor"*.a "${BUILT_PRODUCTS_DIR}/libcurve25519_donna.a"
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
if [[ ${ACTION:-build} = "clean" ]] || [[ $REBUILD = 1 ]]; then
    rm "${BUILT_PRODUCTS_DIR}/libtor.a" 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libor"*.a 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libcurve25519_donna.a" 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libed25519"*.a 2>/dev/null
fi

if [[ $REBUILD = 0 ]]; then
    exit;
fi

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Disable PT_DENY_ATTACH because it is private API
PSEUDO_SYS_INCLUDE_DIR="${CONFIGURATION_TEMP_DIR}/tor-sys"
mkdir -p "${PSEUDO_SYS_INCLUDE_DIR}/sys"
touch "${PSEUDO_SYS_INCLUDE_DIR}/sys/ptrace.h"

if [[ "${ENABLE_BITCODE}" = "YES" ]]; then
    BITCODE_FLAGS="-fembed-bitcode"
fi

# Build each architecture one by one using clang
for ARCH in $ARCHS
do
    HOST=$(xcrun --sdk ${PLATFORM_NAME} clang -arch $ARCH -v 2>&1 | grep Target | sed -e 's/Target: //')
    ./configure --disable-tool-name-check --host="${HOST}" --enable-static-openssl --enable-static-libevent --disable-asciidoc --disable-system-torrc --disable-gcc-hardening --disable-linker-hardening --prefix="${CONFIGURATION_TEMP_DIR}/tor-${ARCH}" --with-libevent-dir="${CONFIGURATION_TEMP_DIR}/libevent-${ARCH}" --with-openssl-dir="${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}" CC="xcrun --sdk ${PLATFORM_NAME} clang -arch ${ARCH}" CFLAGS="${OTHER_CFLAGS} ${BITCODE_FLAGS} -I${PSEUDO_SYS_INCLUDE_DIR} -isysroot ${SDKROOT}" CPPLAGS="${OTHER_CFLAGS} ${BITCODE_FLAGS} -I${PSEUDO_SYS_INCLUDE_DIR} -isysroot ${SDKROOT}" ac_cv_func__NSGetEnviron="no" LDFLAGS="-lz ${OTHER_LDFLAGS} ${BITCODE_FLAGS}"
    make -j$(sysctl hw.ncpu | awk '{print $2}')
    for LIBRARY in src/common/*.a src/or/*.a src/ext/ed25519/donna/*.a src/ext/ed25519/ref10/*.a src/trunnel/*.a;
    do
        cp $LIBRARY "${BUILT_PRODUCTS_DIR}/$(basename ${LIBRARY} .a).${ARCH}.a"
    done
    mv orconfig.h "${CONFIGURATION_TEMP_DIR}/orconfig.h"
    mv micro-revision.i "${CONFIGURATION_TEMP_DIR}/micro-revision.i"
    make distclean
    mv "${CONFIGURATION_TEMP_DIR}/orconfig.h" "${SRCROOT}/Tor/orconfig.h"
    mv "${CONFIGURATION_TEMP_DIR}/micro-revision.i" "${SRCROOT}/Tor/micro-revision.i"
done

# Combine the built products into a fat binary
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libtor."*.a -output "${BUILT_PRODUCTS_DIR}/libtor.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor."*.a -output "${BUILT_PRODUCTS_DIR}/libor.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor-event."*.a -output "${BUILT_PRODUCTS_DIR}/libor-event.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor-crypto."*.a -output "${BUILT_PRODUCTS_DIR}/libor-crypto.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor-trunnel."*.a -output "${BUILT_PRODUCTS_DIR}/libor-trunnel.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libcurve25519_donna."*.a -output "${BUILT_PRODUCTS_DIR}/libcurve25519_donna.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libed25519_donna."*.a -output "${BUILT_PRODUCTS_DIR}/libed25519_donna.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libed25519_ref10."*.a -output "${BUILT_PRODUCTS_DIR}/libed25519_ref10.a"
rm "${BUILT_PRODUCTS_DIR}/libtor"*.*.a
rm "${BUILT_PRODUCTS_DIR}/libor"*.*.a
rm "${BUILT_PRODUCTS_DIR}/libcurve25519_donna."*.a
rm "${BUILT_PRODUCTS_DIR}/libed25519"*.*.a
