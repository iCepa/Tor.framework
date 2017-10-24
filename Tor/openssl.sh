#!/bin/bash

ARCHS=($ARCHS)

REBUILD=0

# If the built binary includes a different set of architectures, then rebuild the target
if [[ ${ACTION:-build} = "build" ]] || [[ $ACTION = "install" ]]; then
    for ARCH in "${ARCHS[@]}"
    do
        if [[ $(lipo -info "${BUILT_PRODUCTS_DIR}/libssl.a" 2>&1) != *"${ARCH}"* ]]; then
            REBUILD=1;
        elif [[ $(lipo -info "${BUILT_PRODUCTS_DIR}/libcrypto.a" 2>&1) != *"${ARCH}"* ]]; then
            REBUILD=1;
        fi
    done
fi

# If rebuilding or cleaning then delete the built products
if [[ $ACTION = "clean" ]] || [[ $REBUILD = 1 ]]; then
    make distclean 2>/dev/null
    rm -r "${BUILT_PRODUCTS_DIR}/openssl-"* 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libssl.a" 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libcrypto.a" 2>/dev/null
fi

if [[ $REBUILD = 0 ]]; then
    exit;
fi

if [[ "${BITCODE_GENERATION_MODE}" = "bitcode" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode"
elif [[ "${BITCODE_GENERATION_MODE}" = "marker" ]]; then
    BITCODE_CFLAGS="-fembed-bitcode-marker"
fi

if [[ "${CONFIGURATION}" = "Debug" ]]; then
    DEBUG_FLAGS="--debug"
else
    DEBUG_FLAGS="--release"
fi

# Build each architecture one by one using clang
for ARCH in "${ARCHS[@]}"
do
    SDK_COMPONENTS=($(echo ${SDKROOT} | sed -e 's/\/SDKs\//\'$'\n/'))
    export CROSS_TOP="${SDK_COMPONENTS[0]}"
    export CROSS_SDK="${SDK_COMPONENTS[1]}"
    export CC="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -arch ${ARCH} ${BITCODE_CFLAGS}"
    if [[ "${ARCH}" == "i386" ]]; then
        ./Configure no-shared no-asm ${DEBUG_FLAGS} --prefix="${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}" darwin-i386-cc
    elif [[ "${ARCH}" == "x86_64" ]]; then
        ./Configure no-shared no-asm enable-ec_nistp_64_gcc_128 ${DEBUG_FLAGS} --prefix="${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}" darwin64-x86_64-cc
    elif [[ "${ARCH}" == "arm64" ]]; then
        ./Configure no-shared no-async zlib-dynamic enable-ec_nistp_64_gcc_128 ${DEBUG_FLAGS} --prefix="${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}" ios64-cross
    else
        ./Configure no-shared no-async zlib-dynamic ${DEBUG_FLAGS} --prefix="${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}" ios-cross
    fi
    make depend
    make -j$(sysctl hw.ncpu | awk '{print $2}') build_libs
    make install_dev
    make distclean
done

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Copy the build products from the temporary directory to the built products directory
for ARCH in "${ARCHS[@]}"
do
    mkdir -p "${BUILT_PRODUCTS_DIR}/openssl-${ARCH}/openssl"
    cp "${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}/include/openssl/opensslconf.h" "${BUILT_PRODUCTS_DIR}/openssl-${ARCH}/openssl"
    for LIBRARY in "${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}/lib/"*.a;
    do
        cp $LIBRARY "${BUILT_PRODUCTS_DIR}/$(basename ${LIBRARY} .a).${ARCH}.a"
    done
done

cp -rf "${BUILT_PRODUCTS_DIR}/openssl-${ARCHS[0]}" "${BUILT_PRODUCTS_DIR}/openssl"

# Combine the built products into a fat binary
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libssl."*.a -output "${BUILT_PRODUCTS_DIR}/libssl.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libcrypto."*.a -output "${BUILT_PRODUCTS_DIR}/libcrypto.a"
rm "${BUILT_PRODUCTS_DIR}/libssl."*.a
rm "${BUILT_PRODUCTS_DIR}/libcrypto."*.a
