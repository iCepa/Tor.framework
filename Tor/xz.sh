#!/bin/bash

ARCHS=($ARCHS)

# We need gettext
# This extends the path to look in some common locations (for example, if installed via Homebrew)
PATH=$PATH:/usr/local/bin:/usr/local/opt/gettext/bin

# Generate the configure script (necessary for version control distributions)
if [[ ! -f ./configure ]]; then
    LIBTOOLIZE=glibtoolize
    ./autogen.sh
fi

REBUILD=0

# If the built binaries include a different set of architectures, then rebuild the target
if [[ ${ACTION:-build} = "build" ]] || [[ $ACTION = "install" ]]; then
    for LIBRARY in "${BUILT_PRODUCTS_DIR}/liblzma"*.a
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
    make distclean 2>/dev/null
    rm -r "${BUILT_PRODUCTS_DIR}/liblzma"* 2>/dev/null
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
    DEBUG_CFLAGS="-g -O0"
    DEBUG_FLAGS="--enable-verbose-debug"
else
    DEBUG_FLAGS=""
fi

# If there is a space in SRCROOT, make a symlink without a space and use that
if [[ "${SRCROOT}" =~ \  ]]; then
    SYM_DIR="$(mktemp -d)/Tor"
    ln -s "${SRCROOT}" "${SYM_DIR}"
    SRCROOT="${SYM_DIR}"
fi

# Build each architecture one by one using clang
for ARCH in "${ARCHS[@]}"
do
    PREFIX="${CONFIGURATION_TEMP_DIR}/liblzma-${ARCH}"
    ./configure --disable-shared --enable-static --disable-doc --disable-scripts --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links ${DEBUG_FLAGS} --prefix="${PREFIX}" CC="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -arch ${ARCH}" CPP="$(xcrun -f --sdk ${PLATFORM_NAME} clang) -E -arch ${ARCH}" CFLAGS="${DEBUG_CFLAGS} ${BITCODE_CFLAGS}" LDFLAGS="-L${BUILT_PRODUCTS_DIR} ${BITCODE_CFLAGS}" cross_compiling="yes" ac_cv_func_clock_gettime="no"
    make -j$(sysctl hw.ncpu | awk '{print $2}')
    make install
    make distclean
done

mkdir -p "${BUILT_PRODUCTS_DIR}"

# Copy the build products from the temporary directory to the built products directory
for ARCH in "${ARCHS[@]}"
do

    mkdir -p "${BUILT_PRODUCTS_DIR}/liblzma-${ARCH}"
    for LIBRARY in "${CONFIGURATION_TEMP_DIR}/liblzma-${ARCH}/lib/"*.a;
    do
        cp $LIBRARY "${BUILT_PRODUCTS_DIR}/$(basename ${LIBRARY} .a).${ARCH}.a"
    done
done

cp -rf "${BUILT_PRODUCTS_DIR}/liblzma-${ARCHS[0]}" "${BUILT_PRODUCTS_DIR}/liblzma"

# Combine the built products into a fat binary
xcrun --sdk $PLATFORM_NAME lipo -create "${BUILT_PRODUCTS_DIR}/liblzma."*.a -output "${BUILT_PRODUCTS_DIR}/liblzma.a"
rm "${BUILT_PRODUCTS_DIR}/liblzma"*.*.a
