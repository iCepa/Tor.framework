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

# If there is a space in BUILT_PRODUCTS_DIR, make a symlink without a space and use that.
if [[ "${BUILT_PRODUCTS_DIR}" =~ \  ]]; then
    SYM_DIR="$(mktemp -d)/bpd"
    ln -s "${BUILT_PRODUCTS_DIR}" "${SYM_DIR}"
    BUILT_PRODUCTS_DIR="${SYM_DIR}"
fi

# If there is a space in CONFIGURATION_TEMP_DIR, make a symlink without a space and use that.
if [[ "${CONFIGURATION_TEMP_DIR}" =~ \  ]]; then
    SYM_DIR="$(mktemp -d)/ctd"
    ln -s "${CONFIGURATION_TEMP_DIR}" "${SYM_DIR}"
    CONFIGURATION_TEMP_DIR="${SYM_DIR}"
fi

# Build each architecture one by one using clang
for ARCH in "${ARCHS[@]}"
do
    export CC="$(xcrun --sdk ${PLATFORM_NAME} --find clang) -isysroot $(xcrun --sdk ${PLATFORM_NAME} --show-sdk-path) -arch ${ARCH} ${BITCODE_CFLAGS}"

    if [[ "${PLATFORM_NAME}" == "iphoneos" ]]; then
        if [[ "${ARCH}" == "arm64" ]]; then
            PLATFORM_FLAGS="no-async zlib-dynamic enable-ec_nistp_64_gcc_128"
            CONFIG="ios64-xcrun"
        elif [[ "${ARCH}" == "armv7" ]]; then
            PLATFORM_FLAGS="no-async zlib-dynamic"
            CONFIG="ios-xcrun"
        else
            echo "OpenSSL configuration error: ${ARCH} on ${PLATFORM_NAME} not supported!"
        fi
    elif [[ "${PLATFORM_NAME}" == "iphonesimulator" ]]; then
        if [[ "${ARCH}" == "arm64" ]]; then
            PLATFORM_FLAGS="no-async zlib-dynamic enable-ec_nistp_64_gcc_128"
            CONFIG="iossimulator-xcrun"
        elif [[ "${ARCH}" == "i386" ]]; then
            PLATFORM_FLAGS="no-asm"
            CONFIG="iossimulator-xcrun"
        elif [[ "${ARCH}" == "x86_64" ]]; then
            PLATFORM_FLAGS="no-asm enable-ec_nistp_64_gcc_128"
            CONFIG="iossimulator-xcrun"
        else
            echo "OpenSSL configuration error: ${ARCH} on ${PLATFORM_NAME} not supported!"
        fi
    elif [[ "${PLATFORM_NAME}" == "macosx" ]]; then
        if [[ "${ARCH}" == "i386" ]]; then
            PLATFORM_FLAGS="no-asm"
            CONFIG="darwin-i386-cc"
        elif [[ "${ARCH}" == "x86_64" ]]; then
            PLATFORM_FLAGS="no-asm enable-ec_nistp_64_gcc_128"
            CONFIG="darwin64-x86_64-cc"
        elif [[ "${ARCH}" == "arm64" ]]; then
            PLATFORM_FLAGS="no-asm enable-ec_nistp_64_gcc_128"
            CONFIG="darwin64-arm64-cc"
        else
            echo "OpenSSL configuration error: ${ARCH} on ${PLATFORM_NAME} not supported!"
        fi
    fi

    if [ -n "${CONFIG}" ]; then
        ./Configure no-shared ${PLATFORM_FLAGS} ${DEBUG_FLAGS} --prefix="${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}" ${CONFIG}

        make depend
        make -j$(sysctl hw.ncpu | awk '{print $2}') build_libs
        make install_dev
        make distclean
    fi
done

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Copy the build products from the temporary directory to the built products directory
for ARCH in "${ARCHS[@]}"
do
    mkdir -p "${BUILT_PRODUCTS_DIR}/openssl-${ARCH}/openssl"

    cp -r "${CONFIGURATION_TEMP_DIR}/openssl-${ARCH}/include/openssl" "${BUILT_PRODUCTS_DIR}/openssl-${ARCH}"

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
