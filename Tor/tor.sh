#!/bin/bash

ARCHS=($ARCHS)

# We need gettext to build tor
# This extends the path to look in some common locations (for example, if installed via Homebrew)
PATH=$PATH:/usr/local/bin:/usr/local/opt/gettext/bin

# Generate the configure script (necessary for version control distributions)
if [[ ! -f ./configure ]]; then
    ./autogen.sh --add-missing
fi

REBUILD=0

# If the built binaries include a different set of architectures, then rebuild the target
if [[ ${ACTION:-build} = "build" ]] || [[ $ACTION = "install" ]]; then
    for LIBRARY in "${BUILT_PRODUCTS_DIR}/libtor.a" "${BUILT_PRODUCTS_DIR}/libor"*.a "${BUILT_PRODUCTS_DIR}/libcurve25519_donna.a" "${BUILT_PRODUCTS_DIR}/libkeccak-tiny.a"
    do
        for ARCH in "${ARCHS[@]}"
        do
            if [[ $(lipo -info "${LIBRARY}" 2>&1) != *"${ARCH}"* ]]; then
                REBUILD=1;
            fi
        done
    done
fi

# If rebuilding or cleaning then delete the built products
if [[ ${ACTION:-build} = "clean" ]] || [[ $REBUILD = 1 ]]; then
    make distclean 2>/dev/null
    rm -r "${BUILT_PRODUCTS_DIR}/tor"* 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libtor.a" 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libor"*.a 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libcurve25519_donna.a" 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libed25519"*.a 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libkeccak-tiny.a" 2>/dev/null
fi

if [[ $REBUILD = 0 ]]; then
    exit;
fi

# Disable PT_DENY_ATTACH because it is private API
PSEUDO_SYS_INCLUDE_DIR="${CONFIGURATION_TEMP_DIR}/tor-sys"
mkdir -p "${PSEUDO_SYS_INCLUDE_DIR}/sys"
touch "${PSEUDO_SYS_INCLUDE_DIR}/sys/ptrace.h"

if [[ "${BITCODE_GENERATION_MODE}" = "bitcode" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode"
elif [[ "${BITCODE_GENERATION_MODE}" = "marker" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode-marker"
fi

if [[ "${CONFIGURATION}" = "Debug" ]]; then
    DEBUG_CFLAGS="-g -O0"
fi

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Build each architecture one by one using clang
for ARCH in "${ARCHS[@]}"
do
    ./configure --disable-lzma --disable-tool-name-check --disable-unittests --enable-static-openssl --enable-static-libevent --disable-asciidoc --disable-system-torrc --disable-linker-hardening --disable-dependency-tracking --prefix="${CONFIGURATION_TEMP_DIR}/tor-${ARCH}" --with-libevent-dir="${BUILT_PRODUCTS_DIR}" --with-openssl-dir="${BUILT_PRODUCTS_DIR}" --enable-lzma CC="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -arch ${ARCH}" CPP="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -E -arch ${ARCH}" CPPFLAGS="${DEBUG_CFLAGS} ${BITCODE_CFLAGS} -I${SRCROOT}/Tor/libevent/include -I${BUILT_PRODUCTS_DIR}/libevent-${ARCH} -I${SRCROOT}/Tor/openssl/include -I${BUILT_PRODUCTS_DIR}/openssl-${ARCH} -I${BUILT_PRODUCTS_DIR}/liblzma-${ARCH} -I${PSEUDO_SYS_INCLUDE_DIR} -isysroot ${SDKROOT}" cross_compiling="yes" ac_cv_func__NSGetEnviron="no" ac_cv_func_clock_gettime="no" ac_cv_func_getentropy="no" LDFLAGS="-lz ${BITCODE_CFLAGS}"
    make -j$(sysctl hw.ncpu | awk '{print $2}')
    for LIBRARY in src/common/*.a src/or/*.a src/ext/ed25519/donna/*.a src/ext/ed25519/ref10/*.a src/trunnel/*.a src/ext/keccak-tiny/*.a;
    do
        cp $LIBRARY "${BUILT_PRODUCTS_DIR}/$(basename ${LIBRARY} .a).${ARCH}.a"
    done
    mkdir -p "${BUILT_PRODUCTS_DIR}/tor-${ARCH}"
    cp orconfig.h "${BUILT_PRODUCTS_DIR}/tor-${ARCH}/orconfig.h"
    cp micro-revision.i "${BUILT_PRODUCTS_DIR}/tor-${ARCH}/micro-revision.i"
    make distclean
done

cp -rf "${BUILT_PRODUCTS_DIR}/tor-${ARCHS[0]}" "${BUILT_PRODUCTS_DIR}/tor"

# Combine the built products into a fat binary
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libtor."*.a -output "${BUILT_PRODUCTS_DIR}/libtor.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor."*.a -output "${BUILT_PRODUCTS_DIR}/libor.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor-event."*.a -output "${BUILT_PRODUCTS_DIR}/libor-event.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor-crypto."*.a -output "${BUILT_PRODUCTS_DIR}/libor-crypto.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor-ctime."*.a -output "${BUILT_PRODUCTS_DIR}/libor-ctime.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libor-trunnel."*.a -output "${BUILT_PRODUCTS_DIR}/libor-trunnel.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libcurve25519_donna."*.a -output "${BUILT_PRODUCTS_DIR}/libcurve25519_donna.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libed25519_donna."*.a -output "${BUILT_PRODUCTS_DIR}/libed25519_donna.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libed25519_ref10."*.a -output "${BUILT_PRODUCTS_DIR}/libed25519_ref10.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libkeccak-tiny."*.a -output "${BUILT_PRODUCTS_DIR}/libkeccak-tiny.a"
rm "${BUILT_PRODUCTS_DIR}/libtor"*.*.a
rm "${BUILT_PRODUCTS_DIR}/libor"*.*.a
rm "${BUILT_PRODUCTS_DIR}/libcurve25519_donna."*.a
rm "${BUILT_PRODUCTS_DIR}/libed25519"*.*.a
rm "${BUILT_PRODUCTS_DIR}/libkeccak-tiny."*.a
