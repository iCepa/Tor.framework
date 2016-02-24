#!/bin/bash

REBUILD=0

# If the built binary includes a different set of architectures, then rebuild the target
if [[ ${ACTION:-build} = "build" ]]; then
    for ARCH in $ARCHS
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
    rm "${BUILT_PRODUCTS_DIR}/libssl.a" 2>/dev/null
    rm "${BUILT_PRODUCTS_DIR}/libcrypto.a" 2>/dev/null
fi

if [[ $REBUILD = 0 ]]; then
    exit;
fi

if [[ "${ENABLE_BITCODE}" = "YES" ]]; then
    BITCODE_FLAGS="-fembed-bitcode"
fi

# Build each architecture one by one using clang
for ARCH in $ARCHS
do
    SDK_COMPONENTS=($(echo ${SDKROOT} | sed -e 's/\/SDKs\//\'$'\n/'))
    export CROSS_TOP="${SDK_COMPONENTS[0]}"
    export CROSS_SDK="${SDK_COMPONENTS[1]}"
    export CC="clang -arch ${ARCH} ${BITCODE_FLAGS}"
    if [ "${ARCH}" == "x86_64" ] || [ "${ARCH}" == "arm64" ]; then
        EC_NISTP="enable-ec_nistp_64_gcc_128"
    fi
    if [ "${ARCH}" == "x86_64" ]; then
        NO_ASM="no-asm"
    fi
    ./Configure iphoneos-cross zlib $NO_ASM $EC_NISTP --openssldir="${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}"
    make -j$(sysctl hw.ncpu | awk '{print $2}')
    make install
    make clean
done

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Copy the build products from the temporary directory to the built products directory
for ARCH in $ARCHS
do
    for LIBRARY in "${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}/lib/"*.a;
    do
        cp $LIBRARY "${BUILT_PRODUCTS_DIR}/$(basename ${LIBRARY} .a).${ARCH}.a"
    done
done

# Combine the built products into a fat binary
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libssl."*.a -output "${BUILT_PRODUCTS_DIR}/libssl.a"
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/libcrypto."*.a -output "${BUILT_PRODUCTS_DIR}/libcrypto.a"
rm "${BUILT_PRODUCTS_DIR}/libssl."*.a
rm "${BUILT_PRODUCTS_DIR}/libcrypto."*.a
